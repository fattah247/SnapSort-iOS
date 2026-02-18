//
//  SmartCategoryService.swift
//  PhotoReviewApp
//
//  Orchestrates fetching photos for smart analysis categories
//

import Photos
import Vision
import OSLog

final class SmartCategoryService {
    private let analysisService: PhotoAnalysisService
    private let cacheManager: AnalysisCacheManager
    private let peopleService: PeopleService
    private let photoService: any PhotoLibraryServiceProtocol

    init(
        analysisService: PhotoAnalysisService,
        cacheManager: AnalysisCacheManager,
        peopleService: PeopleService,
        photoService: any PhotoLibraryServiceProtocol
    ) {
        self.analysisService = analysisService
        self.cacheManager = cacheManager
        self.peopleService = peopleService
        self.photoService = photoService
    }

    // MARK: - Fetch Assets by Smart Category

    func fetchAssets(
        category: SmartCategory,
        limit: Int,
        excluding: Set<String>,
        sortOption: PhotoSortOption = .newestFirst
    ) async -> [PHAsset] {
        switch category {
        case .people:
            // People uses PeopleService, not analysis cache
            return []

        case .duplicates:
            return await fetchDuplicates(limit: limit, excluding: excluding)

        default:
            return await fetchAnalyzedAssets(
                category: category,
                limit: limit,
                excluding: excluding,
                sortOption: sortOption
            )
        }
    }

    // MARK: - Fetch Assets for Person

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

    // MARK: - Counts

    func getCount(for category: SmartCategory) -> Int {
        if category == .people {
            return peopleService.fetchPeopleAlbums().reduce(0) { $0 + $1.assetCount }
        }
        return cacheManager.getAssetIdentifiers(matching: category).count
    }

    func getCategoryCounts() -> [SmartCategory: Int] {
        let stats = cacheManager.getCacheStatistics()
        var counts = stats.byCategory
        counts[.people] = peopleService.fetchPeopleAlbums().reduce(0) { $0 + $1.assetCount }
        return counts
    }

    // MARK: - Analyze On-Demand

    /// Analyzes a batch of assets that haven't been cached yet
    func analyzeIfNeeded(assets: [PHAsset]) async -> [PhotoAnalysisResult] {
        let uncachedIds = cacheManager.getUncachedIdentifiers(
            from: assets.map { $0.localIdentifier }
        )

        if uncachedIds.isEmpty {
            // All cached — return cached results
            return assets.compactMap { cacheManager.getCachedResult(assetIdentifier: $0.localIdentifier) }
        }

        let uncachedAssets = assets.filter { uncachedIds.contains($0.localIdentifier) }
        let newResults = await analysisService.analyzeBatch(assets: uncachedAssets)

        // Combine cached + new results
        var allResults = [PhotoAnalysisResult]()
        for asset in assets {
            if let cached = cacheManager.getCachedResult(assetIdentifier: asset.localIdentifier) {
                allResults.append(cached)
            } else if let newResult = newResults.first(where: { $0.assetIdentifier == asset.localIdentifier }) {
                allResults.append(newResult)
            }
        }
        return allResults
    }

    // MARK: - Duplicate Detection

    func findDuplicates(among identifiers: [String]) async -> [[String]] {
        // Load feature prints from cache
        var featurePrints: [(id: String, observation: VNFeaturePrintObservation)] = []

        for identifier in identifiers {
            guard let result = cacheManager.getCachedResult(assetIdentifier: identifier),
                  let data = result.featurePrintData,
                  let observation = try? NSKeyedUnarchiver.unarchivedObject(
                    ofClass: VNFeaturePrintObservation.self,
                    from: data
                  ) else {
                continue
            }
            featurePrints.append((id: identifier, observation: observation))
        }

        guard featurePrints.count >= 2 else { return [] }

        // Pairwise comparison — partition by month to reduce scope
        var duplicateGroups = [[String]]()
        var assigned = Set<String>()
        let threshold = Constants.Analysis.duplicateDistanceThreshold

        for i in 0..<featurePrints.count {
            guard !assigned.contains(featurePrints[i].id) else { continue }

            var group = [featurePrints[i].id]

            for j in (i + 1)..<min(i + 500, featurePrints.count) {
                guard !assigned.contains(featurePrints[j].id) else { continue }

                var distance: Float = 0
                do {
                    try featurePrints[i].observation.computeDistance(&distance, to: featurePrints[j].observation)
                    if distance < threshold {
                        group.append(featurePrints[j].id)
                    }
                } catch {
                    continue
                }
            }

            if group.count > 1 {
                assigned.formUnion(group)
                duplicateGroups.append(group)
            }
        }

        // Tag duplicates in cache
        for group in duplicateGroups {
            for id in group {
                if var result = cacheManager.getCachedResult(assetIdentifier: id) {
                    result.categories.insert(.duplicates)
                    cacheManager.saveResult(result)
                }
            }
        }

        AppLogger.analysis.info("Found \(duplicateGroups.count) duplicate groups")
        return duplicateGroups
    }

    // MARK: - Private

    private func fetchAnalyzedAssets(
        category: SmartCategory,
        limit: Int,
        excluding: Set<String>,
        sortOption: PhotoSortOption
    ) async -> [PHAsset] {
        let matchingIds = cacheManager.getAssetIdentifiers(matching: category)
        let filteredIds = matchingIds.filter { !excluding.contains($0) }

        guard !filteredIds.isEmpty else { return [] }

        let idsToFetch = Array(filteredIds.prefix(limit * 2)) // Fetch extra in case some are gone
        let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: idsToFetch, options: nil)

        var assets = [PHAsset]()
        fetchResult.enumerateObjects { asset, _, stop in
            if !excluding.contains(asset.localIdentifier) {
                assets.append(asset)
            }
            if assets.count >= limit {
                stop.pointee = true
            }
        }

        // Sort if needed
        switch sortOption {
        case .newestFirst:
            assets.sort { ($0.creationDate ?? .distantPast) > ($1.creationDate ?? .distantPast) }
        case .oldestFirst:
            assets.sort { ($0.creationDate ?? .distantPast) < ($1.creationDate ?? .distantPast) }
        case .random:
            assets.shuffle()
        }

        return Array(assets.prefix(limit))
    }

    private func fetchDuplicates(limit: Int, excluding: Set<String>) async -> [PHAsset] {
        let matchingIds = cacheManager.getAssetIdentifiers(matching: .duplicates)
        let filteredIds = matchingIds.filter { !excluding.contains($0) }

        guard !filteredIds.isEmpty else { return [] }

        let idsToFetch = Array(filteredIds.prefix(limit))
        let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: idsToFetch, options: nil)

        var assets = [PHAsset]()
        fetchResult.enumerateObjects { asset, _, stop in
            assets.append(asset)
            if assets.count >= limit {
                stop.pointee = true
            }
        }

        return assets
    }
}
