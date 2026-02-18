//
//  PhotoCategory.swift
//  PhotoReviewApp
//
//  Photo categories for filtering
//

import Photos
import SwiftUI

enum PhotoCategory: String, CaseIterable, Identifiable {
    case all = "All Photos"
    case screenshots = "Screenshots"
    case selfies = "Selfies"
    case livePhotos = "Live Photos"
    case portraits = "Portrait Mode"
    case panoramas = "Panoramas"
    case bursts = "Bursts"
    case receipts = "Receipts & Docs"
    case recentlyAdded = "Recently Added"
    case favorites = "Favorites"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .all: return "photo.on.rectangle"
        case .screenshots: return "camera.viewfinder"
        case .selfies: return "person.crop.square"
        case .livePhotos: return "livephoto"
        case .portraits: return "person.crop.circle"
        case .panoramas: return "pano"
        case .bursts: return "square.stack.3d.up"
        case .receipts: return "doc.text.viewfinder"
        case .recentlyAdded: return "clock.arrow.circlepath"
        case .favorites: return "heart"
        }
    }

    var color: Color {
        switch self {
        case .all: return AppColors.primary
        case .screenshots: return .orange
        case .selfies: return .pink
        case .livePhotos: return .yellow
        case .portraits: return .purple
        case .panoramas: return .cyan
        case .bursts: return .green
        case .receipts: return .gray
        case .recentlyAdded: return .blue
        case .favorites: return .red
        }
    }

    var description: String {
        switch self {
        case .all: return "Review all your photos"
        case .screenshots: return "Screenshots from your device"
        case .selfies: return "Photos taken with front camera"
        case .livePhotos: return "Photos with motion"
        case .portraits: return "Photos with depth effect"
        case .panoramas: return "Wide panoramic photos"
        case .bursts: return "Burst photo sequences"
        case .receipts: return "Documents and text-heavy images"
        case .recentlyAdded: return "Photos added in the last 30 days"
        case .favorites: return "Photos you've marked as favorites"
        }
    }

    /// Returns the smart album subtype for this category, if applicable
    var smartAlbumSubtype: PHAssetCollectionSubtype? {
        switch self {
        case .screenshots: return .smartAlbumScreenshots
        case .selfies: return .smartAlbumSelfPortraits
        case .livePhotos: return .smartAlbumLivePhotos
        case .portraits: return .smartAlbumDepthEffect
        case .panoramas: return .smartAlbumPanoramas
        case .bursts: return .smartAlbumBursts
        case .recentlyAdded: return .smartAlbumRecentlyAdded
        case .favorites: return .smartAlbumFavorites
        default: return nil
        }
    }

    /// Returns media subtype filter for this category
    var mediaSubtypes: PHAssetMediaSubtype? {
        switch self {
        case .screenshots: return .photoScreenshot
        case .livePhotos: return .photoLive
        case .portraits: return .photoDepthEffect
        case .panoramas: return .photoPanorama
        default: return nil
        }
    }
}

// MARK: - Photo Category Service
class PhotoCategoryService {
    static let shared = PhotoCategoryService()

    private init() {}

    /// Fetches photos from a specific category
    func fetchAssets(
        category: PhotoCategory,
        limit: Int,
        sortDescriptors: [NSSortDescriptor]
    ) -> [PHAsset] {
        // Use smart album if available
        if let subtype = category.smartAlbumSubtype {
            return fetchFromSmartAlbum(subtype: subtype, limit: limit, sortDescriptors: sortDescriptors)
        }

        // For "receipts", we'll use a predicate to find images with text
        if category == .receipts {
            return fetchPotentialDocuments(limit: limit, sortDescriptors: sortDescriptors)
        }

        // Default: fetch all photos
        return fetchAllPhotos(limit: limit, sortDescriptors: sortDescriptors)
    }

    private func fetchFromSmartAlbum(
        subtype: PHAssetCollectionSubtype,
        limit: Int,
        sortDescriptors: [NSSortDescriptor]
    ) -> [PHAsset] {
        let collections = PHAssetCollection.fetchAssetCollections(
            with: .smartAlbum,
            subtype: subtype,
            options: nil
        )

        guard let collection = collections.firstObject else {
            return []
        }

        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = sortDescriptors
        fetchOptions.fetchLimit = limit
        fetchOptions.includeAssetSourceTypes = [.typeUserLibrary, .typeCloudShared, .typeiTunesSynced]

        let result = PHAsset.fetchAssets(in: collection, options: fetchOptions)
        var assets = [PHAsset]()
        result.enumerateObjects { asset, _, _ in
            assets.append(asset)
        }
        return assets
    }

    private func fetchPotentialDocuments(limit: Int, sortDescriptors: [NSSortDescriptor]) -> [PHAsset] {
        // Fetch screenshots as they often contain documents
        // In a full implementation, you'd use Vision framework to detect text
        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = sortDescriptors
        fetchOptions.fetchLimit = limit
        fetchOptions.includeAssetSourceTypes = [.typeUserLibrary, .typeCloudShared, .typeiTunesSynced]

        // Filter for screenshots (often contain receipts, docs, QR codes)
        fetchOptions.predicate = NSPredicate(
            format: "(mediaSubtypes & %d) != 0",
            PHAssetMediaSubtype.photoScreenshot.rawValue
        )

        let result = PHAsset.fetchAssets(with: .image, options: fetchOptions)
        var assets = [PHAsset]()
        result.enumerateObjects { asset, _, _ in
            assets.append(asset)
        }
        return assets
    }

    private func fetchAllPhotos(limit: Int, sortDescriptors: [NSSortDescriptor]) -> [PHAsset] {
        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = sortDescriptors
        fetchOptions.fetchLimit = limit
        fetchOptions.includeAssetSourceTypes = [.typeUserLibrary, .typeCloudShared, .typeiTunesSynced]

        let result = PHAsset.fetchAssets(with: .image, options: fetchOptions)
        var assets = [PHAsset]()
        result.enumerateObjects { asset, _, _ in
            assets.append(asset)
        }
        return assets
    }

    /// Fetches random photos from a category without loading the full result into memory
    func fetchRandomAssets(
        category: PhotoCategory,
        count: Int,
        excluding: Set<String>
    ) -> [PHAsset] {
        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        fetchOptions.includeAssetSourceTypes = [.typeUserLibrary, .typeCloudShared, .typeiTunesSynced]

        let result: PHFetchResult<PHAsset>

        if let subtype = category.smartAlbumSubtype {
            let collections = PHAssetCollection.fetchAssetCollections(
                with: .smartAlbum, subtype: subtype, options: nil
            )
            guard let collection = collections.firstObject else { return [] }
            result = PHAsset.fetchAssets(in: collection, options: fetchOptions)
        } else if category == .receipts {
            fetchOptions.predicate = NSPredicate(
                format: "(mediaSubtypes & %d) != 0",
                PHAssetMediaSubtype.photoScreenshot.rawValue
            )
            result = PHAsset.fetchAssets(with: .image, options: fetchOptions)
        } else {
            result = PHAsset.fetchAssets(with: .image, options: fetchOptions)
        }

        let totalCount = result.count
        guard totalCount > 0 else { return [] }

        var selected = [PHAsset]()
        var usedIndices = Set<Int>()
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

        return selected
    }

    /// Gets the count of photos in a category
    func getCount(for category: PhotoCategory) -> Int {
        if let subtype = category.smartAlbumSubtype {
            let collections = PHAssetCollection.fetchAssetCollections(
                with: .smartAlbum,
                subtype: subtype,
                options: nil
            )
            guard let collection = collections.firstObject else { return 0 }

            let fetchOptions = PHFetchOptions()
            fetchOptions.includeAssetSourceTypes = [.typeUserLibrary, .typeCloudShared, .typeiTunesSynced]
            return PHAsset.fetchAssets(in: collection, options: fetchOptions).count
        }

        if category == .all {
            let fetchOptions = PHFetchOptions()
            fetchOptions.includeAssetSourceTypes = [.typeUserLibrary, .typeCloudShared, .typeiTunesSynced]
            return PHAsset.fetchAssets(with: .image, options: fetchOptions).count
        }

        return 0
    }
}
