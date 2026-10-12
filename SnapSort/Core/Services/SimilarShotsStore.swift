//
//  SimilarShotsStore.swift
//  SnapSort
//
//  Finds sets of near-identical photos (bursts, retakes, accidental doubles)
//  and remembers them between launches.
//
//  Photos are sorted by capture time and each one is compared only with the
//  neighbours taken shortly after it, using Vision feature-print distance.
//  That keeps the work roughly linear in library size.
//

import Foundation
import Vision
import OSLog

struct SimilarShotGroup: Identifiable, Codable, Hashable {
    /// Members in capture order
    let assetIdentifiers: [String]

    var id: String {
        // Changes whenever membership changes, so a dismissed set that later
        // gains a new photo shows up again
        "\(assetIdentifiers.count)|" + assetIdentifiers.joined(separator: ",")
    }
}

final class SimilarShotsStore: @unchecked Sendable {
    private let fileURL: URL
    private let dismissedKey = "dismissedSimilarShotGroups"
    private let lock = NSLock()
    private var cachedGroups: [SimilarShotGroup]?

    init(fileManager: FileManager = .default) {
        let directory = (try? fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )) ?? fileManager.temporaryDirectory
        fileURL = directory.appendingPathComponent("SimilarShots.json")
    }

    // MARK: - Reading

    /// Saved groups the user hasn't dismissed, newest first
    func groups() -> [SimilarShotGroup] {
        let dismissed = dismissedIDs
        return allGroups().filter { !dismissed.contains($0.id) }
    }

    func dismiss(_ group: SimilarShotGroup) {
        var dismissed = dismissedIDs
        dismissed.insert(group.id)
        UserDefaults.standard.set(Array(dismissed), forKey: dismissedKey)
    }

    func clear() {
        lock.withLock { cachedGroups = [] }
        try? FileManager.default.removeItem(at: fileURL)
        UserDefaults.standard.removeObject(forKey: dismissedKey)
    }

    private var dismissedIDs: Set<String> {
        Set(UserDefaults.standard.stringArray(forKey: dismissedKey) ?? [])
    }

    private func allGroups() -> [SimilarShotGroup] {
        if let cached = lock.withLock({ cachedGroups }) { return cached }
        let loaded = (try? Data(contentsOf: fileURL))
            .flatMap { try? JSONDecoder().decode([SimilarShotGroup].self, from: $0) } ?? []
        lock.withLock { cachedGroups = loaded }
        return loaded
    }

    // MARK: - Building

    /// Recomputes groups from cached feature prints and saves them.
    /// - Parameter photos: every analyzed photo with its capture date
    func rebuild(
        from photos: [(identifier: String, date: Date)],
        cache: AnalysisCacheManager
    ) async -> [SimilarShotGroup] {
        let window = Constants.Analysis.similarTimeWindow
        let sorted = photos.sorted { $0.date < $1.date }

        // Only photos with a neighbour close in time can be part of a set
        var candidates = Set<String>()
        for index in sorted.indices.dropLast() where sorted[index + 1].date.timeIntervalSince(sorted[index].date) <= window {
            candidates.insert(sorted[index].identifier)
            candidates.insert(sorted[index + 1].identifier)
        }

        let archived = await cache.featurePrints(for: candidates)
        let groups = Self.group(sorted, archivedPrints: archived)

        lock.withLock { cachedGroups = groups }
        do {
            try JSONEncoder().encode(groups).write(to: fileURL, options: .atomic)
        } catch {
            AppLogger.analysis.error("Failed to save similar shots: \(error.localizedDescription, privacy: .public)")
        }
        AppLogger.analysis.info("Found \(groups.count) sets of similar shots")
        return groups
    }

    static func group(
        _ sorted: [(identifier: String, date: Date)],
        archivedPrints: [String: Data]
    ) -> [SimilarShotGroup] {
        var prints: [Int: SimilaritySignature] = [:]
        for (index, photo) in sorted.enumerated() {
            guard let data = archivedPrints[photo.identifier],
                  let signature = SimilaritySignature(data: data) else { continue }
            prints[index] = signature
        }

        var parent = Array(sorted.indices)
        func root(_ index: Int) -> Int {
            var node = index
            while parent[node] != node {
                parent[node] = parent[parent[node]]
                node = parent[node]
            }
            return node
        }

        let window = Constants.Analysis.similarTimeWindow
        for i in sorted.indices {
            guard let a = prints[i] else { continue }
            var j = i + 1
            while j < sorted.count,
                  j - i <= Constants.Analysis.similarMaxNeighbors,
                  sorted[j].date.timeIntervalSince(sorted[i].date) <= window {
                if let b = prints[j], a.isSimilar(to: b) {
                    parent[root(j)] = root(i)
                }
                j += 1
            }
        }

        var members: [Int: [Int]] = [:]
        for index in prints.keys {
            members[root(index), default: []].append(index)
        }

        return members.values
            .filter { $0.count > 1 }
            .map { $0.sorted() }
            // Newest sets first — indices are already in capture order
            .sorted { ($0.last ?? 0) > ($1.last ?? 0) }
            .map { indices in
                SimilarShotGroup(assetIdentifiers: indices.map { sorted[$0].identifier })
            }
    }
}
