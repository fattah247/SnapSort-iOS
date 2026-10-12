//
//  PhotoAnalysisService.swift
//  SnapSort
//
//  Local on-device photo analysis using Vision & CoreImage.
//  All processing is 100% local — no network calls, no iCloud downloads.
//

import UIKit
import Vision
import CoreImage
import Photos
import ImageIO
import OSLog

// MARK: - Protocol

@MainActor
protocol PhotoAnalysisServiceProtocol: ObservableObject {
    var analysisProgress: AnalysisProgress { get }
    func startBackgroundScan(photoService: any PhotoLibraryServiceProtocol)
    func cancelBackgroundScan()
}

// MARK: - Service

@MainActor
final class PhotoAnalysisService: ObservableObject, PhotoAnalysisServiceProtocol {
    @Published private(set) var analysisProgress = AnalysisProgress()
    /// Bumped whenever a scan finishes, so screens can refresh their counts
    @Published private(set) var lastScanCompletedAt: Date?

    nonisolated let cacheManager: AnalysisCacheManager
    nonisolated let similarShots: SimilarShotsStore
    private var backgroundTask: Task<Void, Never>?
    private var memoryPressureSource: DispatchSourceMemoryPressure?

    private nonisolated let analysisQueue = DispatchQueue(
        label: "com.canoe.snapsort.analysis",
        qos: .utility,
        attributes: .concurrent
    )

    init(cacheManager: AnalysisCacheManager, similarShots: SimilarShotsStore) {
        self.cacheManager = cacheManager
        self.similarShots = similarShots
        setupMemoryMonitoring()
    }

    deinit {
        memoryPressureSource?.cancel()
    }

    // MARK: - Scanning

    /// Analyzes any photos that haven't been analyzed yet. Safe to call often —
    /// it returns quickly when everything is up to date.
    func startBackgroundScan(photoService: any PhotoLibraryServiceProtocol) {
        guard backgroundTask == nil else { return }
        backgroundTask = Task { [weak self] in
            await self?.scanLibrary(photoService: photoService)
            self?.backgroundTask = nil
        }
    }

    /// Forgets every result and analyzes the whole library again
    func resetAndRescan(photoService: any PhotoLibraryServiceProtocol) {
        cancelBackgroundScan()
        backgroundTask = Task { [weak self] in
            guard let self else { return }
            await cacheManager.deleteAll()
            similarShots.clear()
            await scanLibrary(photoService: photoService)
            backgroundTask = nil
        }
    }

    func cancelBackgroundScan() {
        backgroundTask?.cancel()
        backgroundTask = nil
        analysisProgress = AnalysisProgress()
    }

    /// Full scan: discard stale results, analyze new photos, then regroup similar shots.
    func scanLibrary(photoService: any PhotoLibraryServiceProtocol) async {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        guard status == .authorized || status == .limited else { return }

        analysisProgress = AnalysisProgress(isScanning: true, currentPhase: "Getting ready…")
        defer {
            analysisProgress = AnalysisProgress()
            lastScanCompletedAt = Date()
        }

        do {
            let defaults = UserDefaults.standard
            var needsRegrouping = false
            if defaults.integer(forKey: Constants.Analysis.versionDefaultsKey) < Constants.Analysis.version {
                await cacheManager.deleteAll()
                similarShots.clear()
                defaults.set(Constants.Analysis.version, forKey: Constants.Analysis.versionDefaultsKey)
                needsRegrouping = true
            }

            let library = try await photoService.fetchAssets(options: .init(
                limit: 0,
                sortDescriptors: [NSSortDescriptor(key: "creationDate", ascending: false)]
            ))
            let libraryIDs = Set(library.map(\.localIdentifier))

            if await cacheManager.prune(keeping: libraryIDs) > 0 {
                needsRegrouping = true
            }

            let cached = await cacheManager.cachedIdentifiers()
            let pending = library.filter { !cached.contains($0.localIdentifier) }
            analysisProgress.totalPhotos = pending.count
            analysisProgress.analyzedPhotos = 0

            let batchSize = Constants.Analysis.backgroundBatchSize
            for start in stride(from: 0, to: pending.count, by: batchSize) {
                try Task.checkCancellation()

                if Self.isDeviceTooWarm() {
                    analysisProgress.currentPhase = "Taking a breather — your phone is warm"
                    try await Task.sleep(for: .seconds(5))
                }

                analysisProgress.currentPhase = "Looking through your photos…"
                let batch = Array(pending[start..<min(start + batchSize, pending.count)])
                let results = await analyzeBatch(batch)
                await cacheManager.save(results)
                analysisProgress.analyzedPhotos = start + batch.count
                needsRegrouping = needsRegrouping || !results.isEmpty

                try await Task.sleep(for: .seconds(Constants.Analysis.backgroundBatchDelay))
            }

            if needsRegrouping {
                try Task.checkCancellation()
                analysisProgress.currentPhase = "Spotting look-alikes…"
                let photos = library.compactMap { asset in
                    asset.creationDate.map { (identifier: asset.localIdentifier, date: $0) }
                }
                let groups = await similarShots.rebuild(from: photos, cache: cacheManager)
                await cacheManager.setSimilarShotMembers(Set(groups.flatMap(\.assetIdentifiers)))
            }
        } catch is CancellationError {
            AppLogger.analysis.info("Scan cancelled")
        } catch {
            AppLogger.analysis.error("Scan failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - Batch Analysis

    nonisolated func analyzeBatch(_ assets: [PHAsset]) async -> [PhotoAnalysisResult] {
        await withTaskGroup(of: PhotoAnalysisResult?.self) { group in
            var collected = [PhotoAnalysisResult]()
            var iterator = assets.makeIterator()

            func enqueueNext() {
                guard let asset = iterator.next() else { return }
                group.addTask { [self] in
                    guard !Task.isCancelled else { return nil }
                    return await analyze(asset)
                }
            }

            for _ in 0..<Constants.Analysis.maxConcurrentAnalysis {
                enqueueNext()
            }
            for await result in group {
                if let result { collected.append(result) }
                enqueueNext()
            }
            return collected
        }
    }

    /// Analyzes one photo. Returns nil if no local copy is available (iCloud-only).
    nonisolated func analyze(_ asset: PHAsset) async -> PhotoAnalysisResult? {
        guard let loaded = await loadAnalysisImage(for: asset) else { return nil }
        let isScreenshot = asset.mediaSubtypes.contains(.photoScreenshot)
        let identifier = asset.localIdentifier

        return await withCheckedContinuation { continuation in
            analysisQueue.async {
                let result = autoreleasepool {
                    Self.performAnalysis(
                        identifier: identifier,
                        image: loaded.image,
                        orientation: loaded.orientation,
                        isScreenshot: isScreenshot,
                        canJudgeSharpness: loaded.isFullQuality
                    )
                }
                continuation.resume(returning: result)
            }
        }
    }

    // MARK: - Analysis Pipeline

    private nonisolated static let documentLabels: Set<String> = ["document", "printed_page", "receipt", "handwriting", "whiteboard"]
    private nonisolated static let petLabels: Set<String> = ["dog", "cat", "kitten", "adult_cat", "bird", "rabbit", "hamster", "parrot", "horse"]
    private nonisolated static let foodLabels: Set<String> = ["food", "dessert", "pizza", "sushi", "cake", "salad", "bread", "fruit", "vegetable"]
    private nonisolated static let sceneryLabels: Set<String> = [
        "mountain", "beach", "sky", "blue_sky", "sunset_sunrise", "ocean", "lake", "forest", "desert",
        "waterfall", "river", "snow", "cliff", "canyon", "hill", "shore", "volcano", "cityscape", "night_sky"
    ]

    /// Runs entirely off the main thread
    private nonisolated static func performAnalysis(
        identifier: String,
        image: CGImage,
        orientation: CGImagePropertyOrientation,
        isScreenshot: Bool,
        canJudgeSharpness: Bool
    ) -> PhotoAnalysisResult {
        let blur = canJudgeSharpness ? ImageMetrics.blurriness(image) : 0
        let exposure = ImageMetrics.exposure(image)

        // Each request runs on its own so one failure (e.g. a model missing in
        // the simulator) doesn't take the others down with it
        let handler = VNImageRequestHandler(cgImage: image, orientation: orientation)

        let printRequest = VNGenerateImageFeaturePrintRequest()
        try? handler.perform([printRequest])
        let signature = SimilaritySignature(
            pixelHash: ImageMetrics.differenceHash(image),
            featurePrint: printRequest.results?.first
        )

        let faceRequest = VNDetectFaceRectanglesRequest()
        try? handler.perform([faceRequest])
        let faceCount = faceRequest.results?.count ?? 0

        let qrRequest = VNDetectBarcodesRequest()
        qrRequest.symbologies = [.qr]
        try? handler.perform([qrRequest])
        let hasQRCode = !(qrRequest.results?.isEmpty ?? true)

        let classifyRequest = VNClassifyImageRequest()
        try? handler.perform([classifyRequest])
        let classifications = (classifyRequest.results ?? []).sorted { $0.confidence > $1.confidence }
        let labels = classifications
            .filter { $0.confidence >= Constants.Analysis.labelConfidence }
            .map(\.identifier)
        let labelSet = Set(labels)
        let hasDocumentLabel = classifications.contains {
            documentLabels.contains($0.identifier) && $0.confidence >= Constants.Analysis.documentLabelConfidence
        }

        let aestheticsRequest = VNCalculateImageAestheticsScoresRequest()
        try? handler.perform([aestheticsRequest])
        let aesthetics = aestheticsRequest.results?.first
        let isUtility = aesthetics?.isUtility ?? false

        // Decide categories
        var categories = Set<SmartCategory>()
        let looksLikeDocument = isUtility || hasDocumentLabel

        if isScreenshot {
            categories.insert(.screenshots)
        } else if looksLikeDocument {
            categories.insert(.documents)
        }
        if hasQRCode {
            categories.insert(.qrCodes)
        }

        // Quality and subject checks only make sense for camera photos
        if !isScreenshot && !looksLikeDocument && !hasQRCode {
            let aestheticsScore = aesthetics?.overallScore ?? 0
            if blur > Constants.Analysis.blurThreshold
                || (blur > Constants.Analysis.softBlurWithLowAestheticsThreshold
                    && aestheticsScore < Constants.Analysis.blurryAestheticsThreshold) {
                categories.insert(.blurry)
            }

            let lowAesthetics = aestheticsScore < Constants.Analysis.lowAestheticsThreshold
            if exposure?.isTooDark == true
                || exposure?.isTooBright == true
                || (lowAesthetics && blur > Constants.Analysis.softBlurThreshold) {
                categories.insert(.unwanted)
            }

            if faceCount > 0 { categories.insert(.people) }
            if !labelSet.isDisjoint(with: petLabels) { categories.insert(.pets) }
            if !labelSet.isDisjoint(with: foodLabels) { categories.insert(.food) }
            if faceCount == 0, !labelSet.isDisjoint(with: sceneryLabels) { categories.insert(.scenery) }
        }

        return PhotoAnalysisResult(
            assetIdentifier: identifier,
            categories: categories,
            blurScore: blur,
            brightnessScore: exposure?.mean ?? 0.5,
            hasQRCode: hasQRCode,
            sceneLabels: Array(labels.prefix(6)),
            featurePrintData: signature.data,
            analysisDate: Date()
        )
    }

    // MARK: - Image Loading

    private struct LoadedImage {
        let image: CGImage
        let orientation: CGImagePropertyOrientation
        /// False when only a small cached thumbnail was available — too soft to judge blur
        let isFullQuality: Bool
    }

    private nonisolated func loadAnalysisImage(for asset: PHAsset) async -> LoadedImage? {
        if let image = await requestImage(for: asset, deliveryMode: .highQualityFormat) {
            return image
        }
        // No local full-size copy (optimized iCloud storage) — fall back to a thumbnail
        return await requestImage(for: asset, deliveryMode: .fastFormat).map {
            LoadedImage(image: $0.image, orientation: $0.orientation, isFullQuality: false)
        }
    }

    private nonisolated func requestImage(
        for asset: PHAsset,
        deliveryMode: PHImageRequestOptionsDeliveryMode
    ) async -> LoadedImage? {
        let side = Constants.Analysis.imageSize
        return await withCheckedContinuation { continuation in
            let options = PHImageRequestOptions()
            options.deliveryMode = deliveryMode
            options.resizeMode = .fast
            options.isNetworkAccessAllowed = false // Never download from iCloud for analysis
            options.isSynchronous = false

            let lock = NSLock()
            var resumed = false

            PHImageManager.default().requestImage(
                for: asset,
                targetSize: CGSize(width: side, height: side),
                contentMode: .aspectFit,
                options: options
            ) { image, info in
                // Fast format may deliver a single "degraded" result with no follow-up
                let isDegraded = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false
                guard deliveryMode == .fastFormat || !isDegraded || image == nil else { return }

                lock.lock()
                defer { lock.unlock() }
                guard !resumed else { return }
                resumed = true

                guard let image, let cgImage = image.cgImage else {
                    continuation.resume(returning: nil)
                    return
                }
                let isFullQuality = min(cgImage.width, cgImage.height) >= 512
                continuation.resume(returning: LoadedImage(
                    image: cgImage,
                    orientation: CGImagePropertyOrientation(image.imageOrientation),
                    isFullQuality: isFullQuality
                ))
            }
        }
    }

    // MARK: - Memory & Thermal Safeguards

    private func setupMemoryMonitoring() {
        memoryPressureSource = DispatchSource.makeMemoryPressureSource(
            eventMask: [.warning, .critical],
            queue: .global(qos: .utility)
        )
        memoryPressureSource?.setEventHandler { [weak self] in
            Task { @MainActor [weak self] in
                self?.cancelBackgroundScan()
            }
            AppLogger.analysis.warning("Analysis cancelled due to memory pressure")
        }
        memoryPressureSource?.resume()
    }

    private nonisolated static func isDeviceTooWarm() -> Bool {
        let thermal = ProcessInfo.processInfo.thermalState
        return thermal == .serious || thermal == .critical
    }
}

// MARK: - Orientation

extension CGImagePropertyOrientation {
    init(_ orientation: UIImage.Orientation) {
        switch orientation {
        case .up: self = .up
        case .upMirrored: self = .upMirrored
        case .down: self = .down
        case .downMirrored: self = .downMirrored
        case .left: self = .left
        case .leftMirrored: self = .leftMirrored
        case .right: self = .right
        case .rightMirrored: self = .rightMirrored
        @unknown default: self = .up
        }
    }
}
