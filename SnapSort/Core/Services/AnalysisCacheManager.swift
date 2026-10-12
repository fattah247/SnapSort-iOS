//
//  AnalysisCacheManager.swift
//  SnapSort
//
//  CoreData persistence layer for photo analysis results.
//
//  Everything the analysis pipeline touches runs on a private-queue context;
//  only `getCachedResult` uses the view context, for main-thread lookups.
//  `categories` is a Transformable blob, so filtering by category happens in
//  Swift rather than in an NSPredicate.
//

import CoreData
import Photos

final class AnalysisCacheManager: @unchecked Sendable {
    private let context: NSManagedObjectContext
    private let backgroundContext: NSManagedObjectContext

    init(context: NSManagedObjectContext) {
        self.context = context
        self.backgroundContext = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        self.backgroundContext.persistentStoreCoordinator = context.persistentStoreCoordinator
        self.backgroundContext.automaticallyMergesChangesFromParent = true
        self.backgroundContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }

    // MARK: - Main-thread lookup

    /// Single-photo lookup for the review deck. Call on the main thread.
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

    // MARK: - Background reads

    func cachedIdentifiers() async -> Set<String> {
        await backgroundContext.perform { [backgroundContext] in
            let request = NSFetchRequest<NSDictionary>(entityName: "PhotoAnalysisEntity")
            request.resultType = .dictionaryResultType
            request.propertiesToFetch = ["assetIdentifier"]
            let rows = (try? backgroundContext.fetch(request)) ?? []
            return Set(rows.compactMap { $0["assetIdentifier"] as? String })
        }
    }

    /// Photos in each category, keyed by asset identifier
    func membership() async -> [SmartCategory: Set<String>] {
        await backgroundContext.perform { [backgroundContext] in
            let request = PhotoAnalysisEntity.fetchRequest()
            request.returnsObjectsAsFaults = false
            request.propertiesToFetch = ["assetIdentifier", "categories"]

            var result: [SmartCategory: Set<String>] = [:]
            for entity in (try? backgroundContext.fetch(request)) ?? [] {
                for category in entity.smartCategories {
                    result[category, default: []].insert(entity.assetIdentifier)
                }
            }
            return result
        }
    }

    func identifiers(matching category: SmartCategory) async -> [String] {
        Array(await membership()[category] ?? [])
    }

    /// Archived Vision feature prints for the given photos
    func featurePrints(for identifiers: Set<String>) async -> [String: Data] {
        guard !identifiers.isEmpty else { return [:] }
        return await backgroundContext.perform { [backgroundContext] in
            var prints: [String: Data] = [:]
            // Chunk to keep the IN clause reasonable on big libraries
            let all = Array(identifiers)
            for start in stride(from: 0, to: all.count, by: 500) {
                let chunk = Array(all[start..<min(start + 500, all.count)])
                let request = NSFetchRequest<NSDictionary>(entityName: "PhotoAnalysisEntity")
                request.resultType = .dictionaryResultType
                request.propertiesToFetch = ["assetIdentifier", "featurePrintData"]
                request.predicate = NSPredicate(format: "assetIdentifier IN %@", chunk)
                for row in (try? backgroundContext.fetch(request)) ?? [] {
                    if let id = row["assetIdentifier"] as? String, let data = row["featurePrintData"] as? Data {
                        prints[id] = data
                    }
                }
            }
            return prints
        }
    }

    /// Blur and brightness scores, used to pick the best of a set of similar shots
    func qualityScores(for identifiers: [String]) async -> [String: (blur: Float, brightness: Float)] {
        guard !identifiers.isEmpty else { return [:] }
        return await backgroundContext.perform { [backgroundContext] in
            let request = NSFetchRequest<NSDictionary>(entityName: "PhotoAnalysisEntity")
            request.resultType = .dictionaryResultType
            request.propertiesToFetch = ["assetIdentifier", "blurScore", "brightnessScore"]
            request.predicate = NSPredicate(format: "assetIdentifier IN %@", identifiers)
            var scores: [String: (blur: Float, brightness: Float)] = [:]
            for row in (try? backgroundContext.fetch(request)) ?? [] {
                guard let id = row["assetIdentifier"] as? String else { continue }
                scores[id] = (
                    blur: (row["blurScore"] as? NSNumber)?.floatValue ?? 0,
                    brightness: (row["brightnessScore"] as? NSNumber)?.floatValue ?? 0.5
                )
            }
            return scores
        }
    }

    // MARK: - Writes

    func save(_ results: [PhotoAnalysisResult]) async {
        guard !results.isEmpty else { return }
        await backgroundContext.perform { [backgroundContext] in
            let request = PhotoAnalysisEntity.fetchRequest()
            request.predicate = NSPredicate(format: "assetIdentifier IN %@", results.map(\.assetIdentifier))
            var existing: [String: PhotoAnalysisEntity] = [:]
            for entity in (try? backgroundContext.fetch(request)) ?? [] {
                existing[entity.assetIdentifier] = entity
            }
            for result in results {
                let entity = existing[result.assetIdentifier] ?? PhotoAnalysisEntity(context: backgroundContext)
                entity.populate(from: result)
            }
            Self.save(backgroundContext)
        }
    }

    /// Marks exactly `members` as similar shots and clears the flag everywhere else
    func setSimilarShotMembers(_ members: Set<String>) async {
        await backgroundContext.perform { [backgroundContext] in
            let request = PhotoAnalysisEntity.fetchRequest()
            request.returnsObjectsAsFaults = false
            let key = SmartCategory.duplicates.rawValue
            for entity in (try? backgroundContext.fetch(request)) ?? [] {
                var categories = (entity.categories as? [String]) ?? []
                let shouldHave = members.contains(entity.assetIdentifier)
                let has = categories.contains(key)
                if shouldHave && !has {
                    categories.append(key)
                    entity.categories = categories as NSArray
                } else if !shouldHave && has {
                    categories.removeAll { $0 == key }
                    entity.categories = categories as NSArray
                }
            }
            Self.save(backgroundContext)
        }
    }

    /// Removes results for photos that are no longer in the library. Returns how many were removed.
    @discardableResult
    func prune(keeping identifiers: Set<String>) async -> Int {
        await backgroundContext.perform { [backgroundContext] in
            let request = PhotoAnalysisEntity.fetchRequest()
            request.propertiesToFetch = ["assetIdentifier"]
            var removed = 0
            for entity in (try? backgroundContext.fetch(request)) ?? [] where !identifiers.contains(entity.assetIdentifier) {
                backgroundContext.delete(entity)
                removed += 1
            }
            Self.save(backgroundContext)
            return removed
        }
    }

    func deleteAll() async {
        await backgroundContext.perform { [backgroundContext] in
            let request = PhotoAnalysisEntity.fetchRequest()
            for entity in (try? backgroundContext.fetch(request)) ?? [] {
                backgroundContext.delete(entity)
            }
            Self.save(backgroundContext)
            AppLogger.analysis.info("Cleared analysis cache")
        }
    }

    // MARK: - Private

    private static func save(_ context: NSManagedObjectContext) {
        guard context.hasChanges else { return }
        do {
            try context.save()
        } catch {
            AppLogger.analysis.error("Failed to save analysis cache: \(error.localizedDescription, privacy: .public)")
        }
    }
}
