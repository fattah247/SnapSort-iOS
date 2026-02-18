//
//  PHAsset+Extensions.swift
//  PhotoReviewApp
//
//  Created by Muhammad Abdul Fattah on 03/02/25.
//
import Photos

// MARK: - File Size Cache
private actor FileSizeCache {
    private var cache = [String: Int64]()

    func get(_ key: String) -> Int64? {
        cache[key]
    }

    func set(_ key: String, value: Int64) {
        cache[key] = value
    }
}

private let fileSizeCache = FileSizeCache()

extension PHAsset {
    /// Asynchronously fetches the file size - use this to avoid main thread warnings
    func fetchFileSize() async -> Int64 {
        // Check cache first
        if let cached = await fileSizeCache.get(localIdentifier) {
            return cached
        }

        // Fetch on background thread
        let size = await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let resources = PHAssetResource.assetResources(for: self)
                guard let resource = resources.first else {
                    continuation.resume(returning: Int64(0))
                    return
                }

                let size = resource.value(forKey: "fileSize") as? Int64 ?? 0
                continuation.resume(returning: size)
            }
        }

        // Cache the result
        await fileSizeCache.set(localIdentifier, value: size)
        return size
    }

    /// Synchronous file size - only use from background threads
    /// This will show warnings if called from main thread
    var fileSize: Int64 {
        let resources = PHAssetResource.assetResources(for: self)
        guard let resource = resources.first else { return 0 }
        return resource.value(forKey: "fileSize") as? Int64 ?? 0
    }

    var formattedCreationDate: String {
        guard let date = creationDate else { return "Unknown Date" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}

// MARK: - Formatted File Size Helper
extension Int64 {
    var formattedFileSize: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: self)
    }
}
