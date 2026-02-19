//
//  AnalysisCacheManager.swift
//  PhotoReviewApp
//
//  CoreData persistence layer for photo analysis results
//

import CoreData
import Photos

final class AnalysisCacheManager {
    private let context: NSManagedObjectContext
    private let backgroundContext: NSManagedObjectContext

    init(context: NSManagedObjectContext) {
        self.context = context
        self.backgroundContext = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        self.backgroundContext.persistentStoreCoordinator = context.persistentStoreCoordinator
        self.backgroundContext.automaticallyMergesChangesFromParent = true
    }

    // MARK: - Read

    func getCachedResult(assetIdentifier: String) -> PhotoAnalysisResult? {
        let request = PhotoAnalysisEntity.fetchRequest()
        request.predicate = NSPredicate(format: "assetIdentifier == %@", assetIdentifier)
        request.fetchLimit = 1

        do {
            return try context.fetch(request).first?.toResult()
        } catch {
            AppLogger.analysis.error("Failed to fetch cached result: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    func getAssetIdentifiers(matching category: SmartCategory) -> [String] {
        let request = PhotoAnalysisEntity.fetchRequest()
        // categories is a Transformable array of strings — use CONTAINS
        request.predicate = NSPredicate(format: "ANY categories CONTAINS %@", category.rawValue)

        do {
            return try context.fetch(request).map { $0.assetIdentifier }
        } catch {
            // Fallback: fetch all and filter in-memory
            return getAllCachedResults()
                .filter { $0.categories.contains(category) }
                .map { $0.assetIdentifier }
        }
    }

    func getUncachedIdentifiers(from identifiers: [String]) -> [String] {
        let request = PhotoAnalysisEntity.fetchRequest()
        request.predicate = NSPredicate(format: "assetIdentifier IN %@", identifiers)
        request.propertiesToFetch = ["assetIdentifier"]

        do {
            let cached = Set(try context.fetch(request).map { $0.assetIdentifier })
            return identifiers.filter { !cached.contains($0) }
        } catch {
            AppLogger.analysis.error("Failed to fetch cached identifiers: \(error.localizedDescription, privacy: .public)")
            return identifiers
        }
    }

    func getAllCachedResults() -> [PhotoAnalysisResult] {
        let request = PhotoAnalysisEntity.fetchRequest()
        do {
            return try context.fetch(request).map { $0.toResult() }
        } catch {
            AppLogger.analysis.error("Failed to fetch all cached results: \(error.localizedDescription, privacy: .public)")
            return []
        }
    }

    func getCacheStatistics() -> (total: Int, byCategory: [SmartCategory: Int]) {
        var byCategory: [SmartCategory: Int] = [:]

        // Use CoreData count queries to avoid loading all entities into memory
        let totalRequest = PhotoAnalysisEntity.fetchRequest()
        let total = (try? context.count(for: totalRequest)) ?? 0

        for category in SmartCategory.allCases {
            let request = PhotoAnalysisEntity.fetchRequest()
            request.predicate = NSPredicate(format: "ANY categories CONTAINS %@", category.rawValue)
            byCategory[category] = (try? context.count(for: request)) ?? 0
        }

        return (total: total, byCategory: byCategory)
    }

    func getCacheStatisticsAsync() async -> (total: Int, byCategory: [SmartCategory: Int]) {
        await withCheckedContinuation { continuation in
            backgroundContext.perform { [backgroundContext] in
                var byCategory: [SmartCategory: Int] = [:]

                let totalRequest = PhotoAnalysisEntity.fetchRequest()
                let total = (try? backgroundContext.count(for: totalRequest)) ?? 0

                for category in SmartCategory.allCases {
                    let request = PhotoAnalysisEntity.fetchRequest()
                    request.predicate = NSPredicate(format: "ANY categories CONTAINS %@", category.rawValue)
                    byCategory[category] = (try? backgroundContext.count(for: request)) ?? 0
                }

                continuation.resume(returning: (total: total, byCategory: byCategory))
            }
        }
    }

    // MARK: - Write

    func saveResult(_ result: PhotoAnalysisResult) {
        context.perform { [weak self] in
            guard let self else { return }
            self.upsertEntity(from: result)
            self.saveContext()
        }
    }

    func saveBatchResults(_ results: [PhotoAnalysisResult]) {
        guard !results.isEmpty else { return }
        context.perform { [weak self] in
            guard let self else { return }
            for result in results {
                self.upsertEntity(from: result)
            }
            self.saveContext()
        }
    }

    // MARK: - Invalidation

    func invalidateStaleEntries(assets: [PHAsset]) {
        context.perform { [weak self] in
            guard let self else { return }
            for asset in assets {
                let request = PhotoAnalysisEntity.fetchRequest()
                request.predicate = NSPredicate(format: "assetIdentifier == %@", asset.localIdentifier)
                request.fetchLimit = 1

                guard let entity = try? self.context.fetch(request).first else { continue }

                // Re-analyze if photo was edited after last analysis
                if let modDate = asset.modificationDate,
                   let cachedModDate = entity.libraryModDate,
                   modDate > cachedModDate {
                    self.context.delete(entity)
                }
            }
            self.saveContext()
        }
    }

    func clearAllCache() {
        context.perform { [weak self] in
            guard let self else { return }
            let request = PhotoAnalysisEntity.fetchRequest()
            do {
                let entities = try self.context.fetch(request)
                for entity in entities {
                    self.context.delete(entity)
                }
                self.saveContext()
                AppLogger.analysis.info("Cleared all analysis cache (\(entities.count) entries)")
            } catch {
                AppLogger.analysis.error("Failed to clear cache: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    // MARK: - Private

    private func upsertEntity(from result: PhotoAnalysisResult) {
        let request = PhotoAnalysisEntity.fetchRequest()
        request.predicate = NSPredicate(format: "assetIdentifier == %@", result.assetIdentifier)
        request.fetchLimit = 1

        let entity: PhotoAnalysisEntity
        if let existing = try? context.fetch(request).first {
            entity = existing
        } else {
            entity = PhotoAnalysisEntity(context: context)
        }
        entity.populate(from: result)
    }

    private func saveContext() {
        guard context.hasChanges else { return }
        do {
            try context.save()
        } catch {
            AppLogger.analysis.error("Failed to save analysis cache: \(error.localizedDescription, privacy: .public)")
        }
    }
}
