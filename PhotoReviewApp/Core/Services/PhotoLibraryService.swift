//
//  PhotoLibraryManager.swift
//  PhotoReviewApp
//
//  Created by Muhammad Abdul Fattah on 28/01/25.
//
import Photos
import Combine
import SwiftUI
import OSLog

extension NSSortDescriptor: @unchecked @retroactive Sendable {}

protocol PhotoLibraryServiceProtocol: ObservableObject {
    var authorizationStatus: PHAuthorizationStatus { get }
    func requestAuthorization() async -> PHAuthorizationStatus
    func fetchAssets(options: FetchOptions) async throws -> [PHAsset]
    func fetchRandomAssets(count: Int, excluding: Set<String>) async -> [PHAsset]
    func loadImage(for asset: PHAsset, size: CGSize) async -> UIImage?
    func loadLocalImage(for asset: PHAsset, size: CGSize) async -> UIImage?
    func deleteAssets(_ assets: [PHAsset]) async throws
    func getTotalPhotoCount() -> Int
}

final class PhotoLibraryService: PhotoLibraryServiceProtocol {
    @Published private(set) var authorizationStatus: PHAuthorizationStatus = .notDetermined
    private let imageManager = PHCachingImageManager()

    init() {
        imageManager.allowsCachingHighQualityImages = true
    }

    func requestAuthorization() async -> PHAuthorizationStatus {
        await withCheckedContinuation { [weak self] continuation in
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
                DispatchQueue.main.async {
                    self?.authorizationStatus = status
                    continuation.resume(returning: status)
                }
            }
        }
    }

    func fetchAssets(options: FetchOptions) async throws -> [PHAsset] {
        let sortDescriptors = options.sortDescriptors
        let limit = options.limit
        let mediaType = options.mediaType
        let includeHidden = options.includeHidden

        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let fetchOptions = PHFetchOptions()
                fetchOptions.sortDescriptors = sortDescriptors
                fetchOptions.fetchLimit = limit
                fetchOptions.includeHiddenAssets = includeHidden
                fetchOptions.includeAssetSourceTypes = [.typeUserLibrary, .typeCloudShared, .typeiTunesSynced]

                let result = PHAsset.fetchAssets(with: mediaType, options: fetchOptions)
                var assets = [PHAsset]()
                assets.reserveCapacity(result.count)
                result.enumerateObjects { asset, _, _ in
                    assets.append(asset)
                }
                continuation.resume(returning: assets)
            }
        }
    }

    // MARK: - Time-Spread Random Fetch

    func fetchRandomAssets(count: Int, excluding: Set<String>) async -> [PHAsset] {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let fetchOptions = PHFetchOptions()
                fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
                fetchOptions.includeAssetSourceTypes = [.typeUserLibrary, .typeCloudShared, .typeiTunesSynced]

                let result = PHAsset.fetchAssets(with: .image, options: fetchOptions)
                let totalCount = result.count
                guard totalCount > 0 else {
                    continuation.resume(returning: [])
                    return
                }

                // Split the library into time buckets for variety
                let bucketCount = min(Constants.PhotoLoading.randomTimeBuckets, max(1, totalCount / count))
                let bucketSize = totalCount / bucketCount
                let photosPerBucket = max(1, count / bucketCount)

                var selected = [PHAsset]()
                var usedIndices = Set<Int>()

                for bucket in 0..<bucketCount {
                    guard selected.count < count else { break }

                    let bucketStart = bucket * bucketSize
                    let bucketEnd = (bucket == bucketCount - 1) ? totalCount : bucketStart + bucketSize
                    guard bucketStart < bucketEnd else { continue }

                    let needed = min(photosPerBucket + (bucket == bucketCount - 1 ? count - selected.count : 0), count - selected.count)
                    var bucketAttempts = 0
                    let maxBucketAttempts = needed * 4

                    while selected.count < count && bucketAttempts < maxBucketAttempts {
                        let randomIndex = Int.random(in: bucketStart..<bucketEnd)
                        bucketAttempts += 1

                        guard !usedIndices.contains(randomIndex) else { continue }
                        usedIndices.insert(randomIndex)

                        let asset = result.object(at: randomIndex)
                        if !excluding.contains(asset.localIdentifier) {
                            selected.append(asset)
                            if selected.count >= count { break }
                        }
                    }
                }

                continuation.resume(returning: selected)
            }
        }
    }

    // MARK: - Image Loading

    /// Loads an image with iCloud download allowed, but bounded by a timeout.
    func loadImage(for asset: PHAsset, size: CGSize) async -> UIImage? {
        await withTimeoutImage(seconds: Constants.PhotoLoading.imageLoadTimeout) {
            await self.requestImage(for: asset, size: size, allowNetwork: true, deliveryMode: .highQualityFormat)
        }
    }

    /// Loads a locally-cached image only — returns nil instantly if the photo is iCloud-only.
    func loadLocalImage(for asset: PHAsset, size: CGSize) async -> UIImage? {
        await requestImage(for: asset, size: size, allowNetwork: false, deliveryMode: .fastFormat)
    }

    func deleteAssets(_ assets: [PHAsset]) async throws {
        try await PHPhotoLibrary.shared().performChanges {
            PHAssetChangeRequest.deleteAssets(assets as NSArray)
        }
    }

    func getTotalPhotoCount() -> Int {
        let fetchOptions = PHFetchOptions()
        fetchOptions.includeAssetSourceTypes = [.typeUserLibrary, .typeCloudShared, .typeiTunesSynced]
        let result = PHAsset.fetchAssets(with: .image, options: fetchOptions)
        return result.count
    }

    // MARK: - Private

    private func requestImage(
        for asset: PHAsset,
        size: CGSize,
        allowNetwork: Bool,
        deliveryMode: PHImageRequestOptionsDeliveryMode
    ) async -> UIImage? {
        await withCheckedContinuation { continuation in
            let options = PHImageRequestOptions()
            options.isNetworkAccessAllowed = allowNetwork
            options.deliveryMode = deliveryMode
            options.resizeMode = .fast
            options.isSynchronous = false

            var hasResumed = false
            let resumeLock = NSLock()

            imageManager.requestImage(
                for: asset,
                targetSize: size,
                contentMode: .aspectFill,
                options: options
            ) { image, info in
                resumeLock.lock()
                defer { resumeLock.unlock() }

                let isDegraded = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false

                if !hasResumed {
                    if !isDegraded || image != nil {
                        hasResumed = true
                        continuation.resume(returning: image)
                    }
                }
            }
        }
    }

    /// Races an async image load against a timeout.
    private func withTimeoutImage(seconds: TimeInterval, operation: @escaping () async -> UIImage?) async -> UIImage? {
        await withTaskGroup(of: UIImage?.self) { group in
            group.addTask { await operation() }
            group.addTask {
                try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                return nil
            }

            // Return the first non-nil result, or nil if timeout wins
            for await result in group {
                if let image = result {
                    group.cancelAll()
                    return image
                }
            }

            group.cancelAll()
            return nil
        }
    }
}

struct FetchOptions {
    var mediaType: PHAssetMediaType = .image
    var limit: Int = 100
    var sortDescriptors: [NSSortDescriptor] = [NSSortDescriptor(key: "creationDate", ascending: false)]
    var includeHidden: Bool = false
}
