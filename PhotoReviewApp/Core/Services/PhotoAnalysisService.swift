//
//  PhotoAnalysisService.swift
//  PhotoReviewApp
//
//  Local on-device photo analysis using Vision & CoreImage
//  All processing is 100% local — no network calls
//

import UIKit
import Vision
import CoreImage
import Photos
import Combine
import OSLog

// MARK: - Protocol

protocol PhotoAnalysisServiceProtocol: ObservableObject {
    var analysisProgress: AnalysisProgress { get }
    func analyzePhoto(asset: PHAsset, thumbnail: UIImage) async -> PhotoAnalysisResult
    func analyzeBatch(assets: [PHAsset]) async -> [PhotoAnalysisResult]
    func startBackgroundScan(
        photoService: any PhotoLibraryServiceProtocol,
        excluding: Set<String>
    )
    func cancelBackgroundScan()
}

// MARK: - Service

@MainActor
final class PhotoAnalysisService: ObservableObject, PhotoAnalysisServiceProtocol {
    @Published var analysisProgress = AnalysisProgress()

    let cacheManager: AnalysisCacheManager
    private let imageManager: PHCachingImageManager
    private var backgroundTask: Task<Void, Never>?
    private var memoryPressureSource: DispatchSourceMemoryPressure?

    private let analysisQueue = DispatchQueue(
        label: "com.fatarc.PhotoReviewApp.analysis",
        qos: .utility,
        attributes: .concurrent
    )

    // Scene classification keywords mapped to SmartCategory.scenery
    private let sceneryKeywords: Set<String> = [
        "outdoor_mountain", "outdoor_ocean", "outdoor_field",
        "outdoor_forest", "outdoor_lake", "outdoor_beach",
        "outdoor_desert", "outdoor_waterfall", "sky",
        "landscape", "nature", "sunset", "sunrise",
        "outdoor_coast", "outdoor_ice", "outdoor_river",
        "mountain_snowy", "ocean", "lake_natural"
    ]

    init(cacheManager: AnalysisCacheManager) {
        self.cacheManager = cacheManager
        self.imageManager = PHCachingImageManager()
        self.imageManager.allowsCachingHighQualityImages = false
        setupMemoryMonitoring()
    }

    deinit {
        memoryPressureSource?.cancel()
    }

    // MARK: - Single Photo Analysis

    nonisolated func analyzePhoto(asset: PHAsset, thumbnail: UIImage) async -> PhotoAnalysisResult {
        // Check cache first
        if let cached = cacheManager.getCachedResult(assetIdentifier: asset.localIdentifier) {
            // Validate cache isn't stale
            if let modDate = asset.modificationDate,
               cached.analysisDate >= modDate {
                return cached
            }
        }

        // Run analysis pipeline on background queue
        let result = await withCheckedContinuation { continuation in
            analysisQueue.async {
                let analysisResult = autoreleasepool { () -> PhotoAnalysisResult in
                    self.performAnalysis(assetIdentifier: asset.localIdentifier, thumbnail: thumbnail)
                }
                continuation.resume(returning: analysisResult)
            }
        }

        // Cache result
        cacheManager.saveResult(result)
        return result
    }

    // MARK: - Batch Analysis

    nonisolated func analyzeBatch(assets: [PHAsset]) async -> [PhotoAnalysisResult] {
        let maxConcurrent = Constants.Analysis.maxConcurrentAnalysis

        let results = await withTaskGroup(of: PhotoAnalysisResult?.self) { group in
            var collected = [PhotoAnalysisResult]()
            var iterator = assets.makeIterator()

            // Seed initial concurrent tasks
            for _ in 0..<min(maxConcurrent, assets.count) {
                if let asset = iterator.next() {
                    group.addTask { [weak self] in
                        guard let self else { return nil }
                        try? Task.checkCancellation()

                        guard let thumbnail = await self.loadAnalysisThumbnail(for: asset) else {
                            return nil
                        }
                        return await self.analyzePhoto(asset: asset, thumbnail: thumbnail)
                    }
                }
            }

            // Collect results and feed more tasks
            for await result in group {
                if let result {
                    collected.append(result)
                }
                if let asset = iterator.next() {
                    group.addTask { [weak self] in
                        guard let self else { return nil }
                        try? Task.checkCancellation()

                        guard let thumbnail = await self.loadAnalysisThumbnail(for: asset) else {
                            return nil
                        }
                        return await self.analyzePhoto(asset: asset, thumbnail: thumbnail)
                    }
                }
            }
            return collected
        }

        // Batch save to cache
        cacheManager.saveBatchResults(results)
        return results
    }

    // MARK: - Background Scan

    func startBackgroundScan(
        photoService: any PhotoLibraryServiceProtocol,
        excluding: Set<String>
    ) {
        cancelBackgroundScan()

        backgroundTask = Task { [weak self] in
            guard let self else { return }

            await MainActor.run {
                self.analysisProgress = AnalysisProgress(isScanning: true, currentPhase: "Preparing scan...")
            }

            do {
                // Fetch all photo identifiers
                let allAssets = try await photoService.fetchAssets(options: .init(
                    limit: 0,
                    sortDescriptors: [NSSortDescriptor(key: "creationDate", ascending: false)]
                ))

                let eligibleAssets = allAssets.filter { !excluding.contains($0.localIdentifier) }
                let uncachedIds = cacheManager.getUncachedIdentifiers(
                    from: eligibleAssets.map { $0.localIdentifier }
                )

                let uncachedAssets = eligibleAssets.filter { uncachedIds.contains($0.localIdentifier) }

                await MainActor.run {
                    self.analysisProgress.totalPhotos = uncachedAssets.count
                    self.analysisProgress.analyzedPhotos = 0
                }

                if uncachedAssets.isEmpty {
                    await MainActor.run {
                        self.analysisProgress = AnalysisProgress()
                    }
                    return
                }

                // Process in batches
                let batchSize = Constants.Analysis.backgroundBatchSize
                for batchStart in stride(from: 0, to: uncachedAssets.count, by: batchSize) {
                    try Task.checkCancellation()

                    // Check thermal state
                    if shouldPauseAnalysis() {
                        await MainActor.run {
                            self.analysisProgress.currentPhase = "Paused (device is warm)"
                        }
                        try await Task.sleep(nanoseconds: 5_000_000_000) // 5 seconds
                        continue
                    }

                    let batchEnd = min(batchStart + batchSize, uncachedAssets.count)
                    let batch = Array(uncachedAssets[batchStart..<batchEnd])

                    await MainActor.run {
                        self.analysisProgress.currentPhase = "Analyzing photos..."
                    }

                    let _ = await analyzeBatch(assets: batch)

                    await MainActor.run {
                        self.analysisProgress.analyzedPhotos = batchEnd
                    }

                    // Yield to prevent UI freezing
                    try await Task.sleep(nanoseconds: UInt64(Constants.Analysis.backgroundBatchDelay * 1_000_000_000))
                }

            } catch is CancellationError {
                AppLogger.analysis.info("Background scan cancelled")
            } catch {
                AppLogger.analysis.error("Background scan error: \(error.localizedDescription, privacy: .public)")
            }

            await MainActor.run {
                self.analysisProgress = AnalysisProgress()
            }
        }
    }

    func cancelBackgroundScan() {
        backgroundTask?.cancel()
        backgroundTask = nil
        analysisProgress = AnalysisProgress()
    }

    // MARK: - Analysis Pipeline

    /// Core analysis pipeline — runs entirely off main thread inside autoreleasepool
    private nonisolated func performAnalysis(assetIdentifier: String, thumbnail: UIImage) -> PhotoAnalysisResult {
        let blurScore = detectBlur(image: thumbnail)
        let brightnessScore = analyzeBrightness(image: thumbnail)
        let hasQRCode = detectQRCode(image: thumbnail)
        let sceneLabels = classifyScene(image: thumbnail)
        let featurePrintData = generateFeaturePrint(image: thumbnail)

        // Determine categories
        var categories = Set<SmartCategory>()

        if blurScore > Constants.Analysis.blurThreshold {
            categories.insert(.blurry)
        }

        if brightnessScore < Constants.Analysis.darkThreshold
            || brightnessScore > Constants.Analysis.brightThreshold {
            categories.insert(.probablyUnwanted)
        }

        if hasQRCode {
            categories.insert(.qrCodes)
        }

        if sceneLabels.contains(where: { sceneryKeywords.contains($0) }) {
            categories.insert(.scenery)
        }

        return PhotoAnalysisResult(
            assetIdentifier: assetIdentifier,
            categories: categories,
            blurScore: blurScore,
            brightnessScore: brightnessScore,
            hasQRCode: hasQRCode,
            sceneLabels: sceneLabels,
            featurePrintData: featurePrintData,
            analysisDate: Date()
        )
    }

    // MARK: - Blur Detection (CIImage Laplacian Variance)

    private nonisolated func detectBlur(image: UIImage) -> Float {
        autoreleasepool {
            guard let cgImage = image.cgImage else { return 0 }
            let ciImage = CIImage(cgImage: cgImage)

            // Apply Laplacian filter to detect edges
            guard let filter = CIFilter(name: "CIConvolution3X3") else { return 0 }
            filter.setValue(ciImage, forKey: kCIInputImageKey)

            // Laplacian kernel for edge detection
            let laplacianKernel = CIVector(values: [0, 1, 0, 1, -4, 1, 0, 1, 0], count: 9)
            filter.setValue(laplacianKernel, forKey: "inputWeights")
            filter.setValue(0, forKey: "inputBias")

            guard let outputImage = filter.outputImage else { return 0 }

            // Compute extent statistics to get variance
            let context = CIContext(options: [.useSoftwareRenderer: true])
            guard let extent = outputImage.extent.isEmpty ? nil : outputImage.extent as CGRect? else { return 0 }

            // Sample pixels to compute variance
            let sampleSize = CGSize(width: min(50, extent.width), height: min(50, extent.height))
            guard let bitmap = context.createCGImage(outputImage, from: CGRect(origin: extent.origin, size: sampleSize)) else {
                return 0
            }

            let dataProvider = bitmap.dataProvider
            guard let data = dataProvider?.data,
                  let bytes = CFDataGetBytePtr(data) else { return 0 }

            let bytesPerPixel = bitmap.bitsPerPixel / 8
            let pixelCount = bitmap.width * bitmap.height
            guard pixelCount > 0 else { return 0 }

            var sum: Float = 0
            var sumSquared: Float = 0

            for i in 0..<pixelCount {
                let offset = i * bytesPerPixel
                let value = Float(bytes[offset]) / 255.0
                sum += value
                sumSquared += value * value
            }

            let mean = sum / Float(pixelCount)
            let variance = (sumSquared / Float(pixelCount)) - (mean * mean)

            // Low variance = blurry (edges are weak). Invert so higher = blurrier.
            // Typical variance ranges: sharp ~0.02-0.1, blurry ~0.0-0.005
            let normalizedBlur = max(0, min(1, 1.0 - (variance * 100)))
            return normalizedBlur
        }
    }

    // MARK: - Brightness Analysis

    private nonisolated func analyzeBrightness(image: UIImage) -> Float {
        autoreleasepool {
            guard let cgImage = image.cgImage else { return 0.5 }

            let width = cgImage.width
            let height = cgImage.height
            let totalPixels = width * height
            guard totalPixels > 0 else { return 0.5 }

            // Create a small grayscale bitmap to compute average luminance
            let colorSpace = CGColorSpaceCreateDeviceGray()
            guard let context = CGContext(
                data: nil,
                width: min(width, 50),
                height: min(height, 50),
                bitsPerComponent: 8,
                bytesPerRow: min(width, 50),
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.none.rawValue
            ) else { return 0.5 }

            let drawWidth = min(width, 50)
            let drawHeight = min(height, 50)
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: drawWidth, height: drawHeight))

            guard let data = context.data else { return 0.5 }
            let bytes = data.bindMemory(to: UInt8.self, capacity: drawWidth * drawHeight)

            var totalLuminance: Float = 0
            let samplePixels = drawWidth * drawHeight
            for i in 0..<samplePixels {
                totalLuminance += Float(bytes[i]) / 255.0
            }

            return totalLuminance / Float(samplePixels)
        }
    }

    // MARK: - QR Code Detection (Vision)

    private nonisolated func detectQRCode(image: UIImage) -> Bool {
        autoreleasepool {
            guard let cgImage = image.cgImage else { return false }

            let request = VNDetectBarcodesRequest()
            request.symbologies = [.qr]

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
                return !(request.results?.isEmpty ?? true)
            } catch {
                return false
            }
        }
    }

    // MARK: - Scene Classification (Vision)

    private nonisolated func classifyScene(image: UIImage) -> [String] {
        autoreleasepool {
            guard let cgImage = image.cgImage else { return [] }

            let request = VNClassifyImageRequest()

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
                guard let results = request.results else { return [] }

                // Return top classifications with confidence > 0.3
                return results
                    .filter { $0.confidence > 0.3 }
                    .prefix(5)
                    .map { $0.identifier }
            } catch {
                return []
            }
        }
    }

    // MARK: - Feature Print Generation (Vision)

    private nonisolated func generateFeaturePrint(image: UIImage) -> Data? {
        autoreleasepool {
            guard let cgImage = image.cgImage else { return nil }

            let request = VNGenerateImageFeaturePrintRequest()

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
                guard let observation = request.results?.first as? VNFeaturePrintObservation else {
                    return nil
                }

                // Serialize the feature print for storage
                let data = try NSKeyedArchiver.archivedData(
                    withRootObject: observation,
                    requiringSecureCoding: true
                )
                return data
            } catch {
                return nil
            }
        }
    }

    // MARK: - Thumbnail Loading

    nonisolated func loadAnalysisThumbnail(for asset: PHAsset) async -> UIImage? {
        let size = CGSize(
            width: Constants.Analysis.thumbnailSize,
            height: Constants.Analysis.thumbnailSize
        )

        return await withCheckedContinuation { continuation in
            let options = PHImageRequestOptions()
            options.deliveryMode = .fastFormat
            options.resizeMode = .fast
            options.isNetworkAccessAllowed = false // Never download from iCloud for analysis
            options.isSynchronous = false

            imageManager.requestImage(
                for: asset,
                targetSize: size,
                contentMode: .aspectFit,
                options: options
            ) { image, info in
                let isDegraded = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false
                if !isDegraded {
                    continuation.resume(returning: image)
                }
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

    private nonisolated func shouldPauseAnalysis() -> Bool {
        let thermal = ProcessInfo.processInfo.thermalState
        return thermal == .serious || thermal == .critical
    }
}
