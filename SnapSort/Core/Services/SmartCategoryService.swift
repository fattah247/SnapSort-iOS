//
//  SmartCategoryService.swift
//  SnapSort
//
//  Answers "which photos are in this smart group?" from the analysis cache,
//  or straight from PhotoKit for metadata-only groups like long videos.
//

import Photos
import OSLog

final class SmartCategoryService: @unchecked Sendable {
    private let cacheManager: AnalysisCacheManager
    private let peopleService: PeopleService
    let similarShots: SimilarShotsStore

    init(
        cacheManager: AnalysisCacheManager,
        peopleService: PeopleService,
        similarShots: SimilarShotsStore
    ) {
        self.cacheManager = cacheManager
        self.peopleService = peopleService
        self.similarShots = similarShots
    }

    // MARK: - Membership

    /// Every smart group's members, keyed by asset identifier
    func membership() async -> [SmartCategory: Set<String>] {
        var members = await cacheManager.membership()
        members[.longVideos] = Set(longVideoResult().identifiers)
        return members
    }

    // MARK: - Fetch Assets by Smart Category

    func fetchAssets(
        category: SmartCategory,
        limit: Int,
        excluding: Set<String>,
        sortOption: PhotoSortOption = .newestFirst
    ) async -> [PHAsset] {
        if category == .longVideos {
            // Biggest first is the only order that makes sense here
            return Self.firstAssets(in: longVideoResult(), limit: limit, excluding: excluding)
        }

        let identifiers = await cacheManager.identifiers(matching: category)
            .filter { !excluding.contains($0) }
        guard !identifiers.isEmpty else { return [] }

        let options = PHFetchOptions()
        if sortOption != .random {
            options.sortDescriptors = sortOption.sortDescriptors
        }
        let result = PHAsset.fetchAssets(withLocalIdentifiers: identifiers, options: options)

        if sortOption == .random {
            let indices = Array(0..<result.count).shuffled().prefix(limit)
            return indices.map { result.object(at: $0) }
        }
        return Self.firstAssets(in: result, limit: limit, excluding: excluding)
    }

    // MARK: - People Albums

    func fetchAssetsForPerson(
        _ person: PersonAlbum,
        limit: Int,
        excluding: Set<String>,
        sortOption: PhotoSortOption = .newestFirst
    ) -> [PHAsset] {
        if sortOption == .random {
            return peopleService.fetchRandomAssets(for: person, count: limit, excluding: excluding)
        }
        return peopleService.fetchAssets(for: person, limit: limit, excluding: excluding)
    }

    // MARK: - Private

    private func longVideoResult() -> PHFetchResult<PHAsset> {
        let options = PHFetchOptions()
        options.predicate = NSPredicate(format: "duration >= %f", Constants.Analysis.longVideoDuration)
        options.sortDescriptors = [NSSortDescriptor(key: "duration", ascending: false)]
        options.includeAssetSourceTypes = [.typeUserLibrary, .typeCloudShared, .typeiTunesSynced]
        return PHAsset.fetchAssets(with: .video, options: options)
    }

    private static func firstAssets(in result: PHFetchResult<PHAsset>, limit: Int, excluding: Set<String>) -> [PHAsset] {
        var assets = [PHAsset]()
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
}

private extension PHFetchResult where ObjectType == PHAsset {
    var identifiers: [String] {
        var ids = [String]()
        ids.reserveCapacity(count)
        enumerateObjects { asset, _, _ in ids.append(asset.localIdentifier) }
        return ids
    }
}
