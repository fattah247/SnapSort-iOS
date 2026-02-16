//
//  PhotoLibraryManager.swift
//  PhotoReviewApp
//
//  Created by Muhammad Abdul Fattah on 28/01/25.
//
import Photos
import Combine
import CoreData
import SwiftUI
import OSLog

extension NSSortDescriptor: @unchecked @retroactive Sendable {}

protocol PhotoLibraryServiceProtocol: ObservableObject {
    var authorizationStatus: PHAuthorizationStatus { get }
    func requestAuthorization() async -> PHAuthorizationStatus
    func fetchAssets(options: FetchOptions) async throws -> [PHAsset]
    func fetchRandomAssets(count: Int, excluding: Set<String>) async -> [PHAsset]
    func loadImage(for asset: PHAsset, size: CGSize) async -> UIImage?
    func deleteAssets(_ assets: [PHAsset]) async throws
    func getTotalPhotoCount() -> Int
}

final class PhotoLibraryService: PhotoLibraryServiceProtocol {
    @Published private(set) var authorizationStatus: PHAuthorizationStatus = .notDetermined
    private let imageManager = PHCachingImageManager()

    init() {
        // Allow iCloud photo downloads
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

                // Include ALL source types (local, iCloud, iTunes sync)
                fetchOptions.includeAssetSourceTypes = [.typeUserLibrary, .typeCloudShared, .typeiTunesSynced]

                let result = PHAsset.fetchAssets(with: mediaType, options: fetchOptions)
                var assets = [PHAsset]()
                result.enumerateObjects { asset, _, _ in
                    assets.append(asset)
                }
                continuation.resume(returning: assets)
            }
        }
    }

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

                // Pick random indices from the fetch result without loading everything
                var selected = [PHAsset]()
                var usedIndices = Set<Int>()
                // Try up to 3x the requested count to account for exclusions
                let maxAttempts = min(count * 3, totalCount)
                var attempts = 0

                while selected.count < count && attempts < maxAttempts {
                    let randomIndex = Int.random(in: 0..<totalCount)
                    guard !usedIndices.contains(randomIndex) else {
                        attempts += 1
                        continue
                    }
                    usedIndices.insert(randomIndex)
                    attempts += 1

                    let asset = result.object(at: randomIndex)
                    if !excluding.contains(asset.localIdentifier) {
                        selected.append(asset)
                    }
                }

                continuation.resume(returning: selected)
            }
        }
    }

    func loadImage(for asset: PHAsset, size: CGSize) async -> UIImage? {
        await withCheckedContinuation { continuation in
            let requestOptions = PHImageRequestOptions()
            requestOptions.isNetworkAccessAllowed = true // Allow iCloud download
            requestOptions.deliveryMode = .highQualityFormat
            requestOptions.resizeMode = .exact
            requestOptions.isSynchronous = false

            // Use a flag to ensure we only resume once (requestImage can call handler multiple times)
            var hasResumed = false
            let resumeLock = NSLock()

            imageManager.requestImage(
                for: asset,
                targetSize: size,
                contentMode: .aspectFill,
                options: requestOptions
            ) { image, info in
                resumeLock.lock()
                defer { resumeLock.unlock() }

                // Check if this is the final image (not degraded)
                let isDegraded = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false

                // Resume only once with the best available image
                if !hasResumed {
                    if !isDegraded || image != nil {
                        hasResumed = true
                        continuation.resume(returning: image)
                    }
                }
            }
        }
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
}

struct FetchOptions {
    var mediaType: PHAssetMediaType = .image
    var limit: Int = 100
    var sortDescriptors: [NSSortDescriptor] = [NSSortDescriptor(key: "creationDate", ascending: false)]
    var includeHidden: Bool = false
}
