//
//  PhotoCategory.swift
//  SnapSort
//
//  Library filters for the review deck
//

import Photos
import SwiftUI

enum PhotoCategory: String, CaseIterable, Identifiable {
    case all = "All Photos"
    case videos = "Videos"
    case screenshots = "Screenshots"
    case selfies = "Selfies"
    case livePhotos = "Live Photos"
    case portraits = "Portrait Mode"
    case panoramas = "Panoramas"
    case bursts = "Bursts"
    case recentlyAdded = "Recently Added"
    case favorites = "Favorites"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .all: return "photo.on.rectangle"
        case .videos: return "video"
        case .screenshots: return "camera.viewfinder"
        case .selfies: return "person.crop.square"
        case .livePhotos: return "livephoto"
        case .portraits: return "cube"
        case .panoramas: return "pano"
        case .bursts: return "square.stack.3d.up"
        case .recentlyAdded: return "clock.arrow.circlepath"
        case .favorites: return "heart"
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
        case .all, .videos: return nil
        }
    }

    var mediaType: PHAssetMediaType {
        self == .videos ? .video : .image
    }
}

// MARK: - Photo Category Service

final class PhotoCategoryService: @unchecked Sendable {
    static let shared = PhotoCategoryService()

    private init() {}

    /// Returns up to `limit` items from a category in sort order, skipping
    /// excluded identifiers. Walks the lazy fetch result instead of using
    /// `fetchLimit`, so already-reviewed photos don't exhaust the window.
    func fetchAssets(
        category: PhotoCategory,
        limit: Int,
        sortDescriptors: [NSSortDescriptor],
        excluding: Set<String> = [],
        dateRange: Range<Date>? = nil
    ) -> [PHAsset] {
        guard let result = fetchResult(for: category, sortDescriptors: sortDescriptors, dateRange: dateRange) else { return [] }

        var assets = [PHAsset]()
        assets.reserveCapacity(limit)
        result.enumerateObjects { asset, _, stop in
            if !excluding.contains(asset.localIdentifier) {
                assets.append(asset)
            }
            if assets.count >= limit {
                stop.pointee = true
            }
        }
        return assets
    }

    /// Random items from a category without loading the whole result into memory
    func fetchRandomAssets(
        category: PhotoCategory,
        count: Int,
        excluding: Set<String>,
        dateRange: Range<Date>? = nil
    ) -> [PHAsset] {
        guard let result = fetchResult(
            for: category,
            sortDescriptors: [NSSortDescriptor(key: "creationDate", ascending: false)],
            dateRange: dateRange
        ) else { return [] }

        let total = result.count
        guard total > 0 else { return [] }

        var selected = [PHAsset]()
        var used = Set<Int>()
        var attempts = 0
        while selected.count < count, attempts < count * 6, used.count < total {
            attempts += 1
            let index = Int.random(in: 0..<total)
            guard used.insert(index).inserted else { continue }
            let asset = result.object(at: index)
            if !excluding.contains(asset.localIdentifier) {
                selected.append(asset)
            }
        }

        // Most of the category has been reviewed — sweep from a random start instead
        if selected.count < count {
            let start = Int.random(in: 0..<total)
            for offset in 0..<total where selected.count < count {
                let index = (start + offset) % total
                guard !used.contains(index) else { continue }
                let asset = result.object(at: index)
                if !excluding.contains(asset.localIdentifier) {
                    selected.append(asset)
                }
            }
        }

        return selected
    }

    /// The years that have at least one item, newest first
    func availableYears() -> [Int] {
        let calendar = Calendar.current
        func edgeDate(ascending: Bool) -> Date? {
            let options = PHFetchOptions()
            options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: ascending)]
            options.fetchLimit = 1
            options.includeAssetSourceTypes = [.typeUserLibrary, .typeCloudShared, .typeiTunesSynced]
            return PHAsset.fetchAssets(with: options).firstObject?.creationDate
        }
        guard let oldest = edgeDate(ascending: true), let newest = edgeDate(ascending: false) else { return [] }
        let first = calendar.component(.year, from: oldest)
        let last = calendar.component(.year, from: newest)
        guard first <= last else { return [] }
        return Array((first...last).reversed())
    }

    private func fetchResult(
        for category: PhotoCategory,
        sortDescriptors: [NSSortDescriptor],
        dateRange: Range<Date>?
    ) -> PHFetchResult<PHAsset>? {
        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = sortDescriptors.isEmpty ? nil : sortDescriptors
        fetchOptions.includeAssetSourceTypes = [.typeUserLibrary, .typeCloudShared, .typeiTunesSynced]
        if let dateRange {
            fetchOptions.predicate = NSPredicate(
                format: "creationDate >= %@ AND creationDate < %@",
                dateRange.lowerBound as NSDate,
                dateRange.upperBound as NSDate
            )
        }

        if let subtype = category.smartAlbumSubtype {
            let collections = PHAssetCollection.fetchAssetCollections(
                with: .smartAlbum,
                subtype: subtype,
                options: nil
            )
            guard let collection = collections.firstObject else { return nil }
            return PHAsset.fetchAssets(in: collection, options: fetchOptions)
        }

        return PHAsset.fetchAssets(with: category.mediaType, options: fetchOptions)
    }
}

extension Int {
    /// January 1 of this year up to January 1 of the next
    var yearRange: Range<Date>? {
        let calendar = Calendar.current
        guard let start = calendar.date(from: DateComponents(year: self, month: 1, day: 1)),
              let end = calendar.date(byAdding: .year, value: 1, to: start) else { return nil }
        return start..<end
    }
}
