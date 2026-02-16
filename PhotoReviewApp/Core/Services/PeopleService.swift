//
//  PeopleService.swift
//  PhotoReviewApp
//
//  Service for fetching People albums (Apple built-in) with Vision fallback
//

import Photos
import Vision
import UIKit
import OSLog

// MARK: - Person Album Model

struct PersonAlbum: Identifiable, Equatable {
    let id: String              // PHAssetCollection.localIdentifier
    let name: String            // User-assigned name or "Unknown"
    let assetCount: Int
    let keyAsset: PHAsset?      // For thumbnail display

    static func == (lhs: PersonAlbum, rhs: PersonAlbum) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Protocol

protocol PeopleServiceProtocol {
    func fetchPeopleAlbums() -> [PersonAlbum]
    func fetchAssets(for person: PersonAlbum, limit: Int, excluding: Set<String>) -> [PHAsset]
    func fetchAllAssets(for person: PersonAlbum) -> [PHAsset]
    var hasPeopleAlbums: Bool { get }
}

// MARK: - Service

final class PeopleService: PeopleServiceProtocol {

    // Cache people albums to avoid repeated fetches
    private var cachedAlbums: [PersonAlbum]?
    private var lastFetchDate: Date?
    private let cacheLifetime: TimeInterval = 300 // 5 minutes

    var hasPeopleAlbums: Bool {
        !fetchPeopleAlbums().isEmpty
    }

    // MARK: - Fetch People Albums

    func fetchPeopleAlbums() -> [PersonAlbum] {
        // Return cache if fresh
        if let cached = cachedAlbums,
           let fetchDate = lastFetchDate,
           Date().timeIntervalSince(fetchDate) < cacheLifetime {
            return cached
        }

        var albums = [PersonAlbum]()

        // Fetch Person smart folders from Photos
        let personCollections = PHCollectionList.fetchCollectionLists(
            with: .smartFolder,
            subtype: .smartFolderFaces,
            options: nil
        )

        personCollections.enumerateObjects { collectionList, _, _ in
            // Each person is a collection list containing one smart album
            let innerCollections = PHAssetCollection.fetchCollections(
                in: collectionList,
                options: nil
            )

            innerCollections.enumerateObjects { collection, _, _ in
                guard let assetCollection = collection as? PHAssetCollection else { return }

                let fetchOptions = PHFetchOptions()
                fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
                fetchOptions.includeAssetSourceTypes = [.typeUserLibrary, .typeCloudShared, .typeiTunesSynced]

                let assets = PHAsset.fetchAssets(in: assetCollection, options: fetchOptions)
                let count = assets.count
                guard count > 0 else { return }

                let name = collectionList.localizedTitle ?? "Unknown"
                let keyAsset = assets.firstObject

                albums.append(PersonAlbum(
                    id: assetCollection.localIdentifier,
                    name: name,
                    assetCount: count,
                    keyAsset: keyAsset
                ))
            }
        }

        // Sort by asset count (most photos first)
        albums.sort { $0.assetCount > $1.assetCount }

        cachedAlbums = albums
        lastFetchDate = Date()

        AppLogger.analysis.info("Fetched \(albums.count) people albums")
        return albums
    }

    // MARK: - Fetch Assets for Person

    func fetchAssets(for person: PersonAlbum, limit: Int, excluding: Set<String>) -> [PHAsset] {
        let result = fetchPersonAssets(collectionId: person.id)
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

    func fetchAllAssets(for person: PersonAlbum) -> [PHAsset] {
        let result = fetchPersonAssets(collectionId: person.id)
        var assets = [PHAsset]()
        result.enumerateObjects { asset, _, _ in
            assets.append(asset)
        }
        return assets
    }

    // MARK: - Random Assets for Person

    func fetchRandomAssets(for person: PersonAlbum, count: Int, excluding: Set<String>) -> [PHAsset] {
        let result = fetchPersonAssets(collectionId: person.id)
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

    // MARK: - Cache Invalidation

    func invalidateCache() {
        cachedAlbums = nil
        lastFetchDate = nil
    }

    // MARK: - Private

    private func fetchPersonAssets(collectionId: String) -> PHFetchResult<PHAsset> {
        let collections = PHAssetCollection.fetchAssetCollections(
            withLocalIdentifiers: [collectionId],
            options: nil
        )

        guard let collection = collections.firstObject else {
            return PHAsset.fetchAssets(withLocalIdentifiers: [], options: nil)
        }

        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        fetchOptions.includeAssetSourceTypes = [.typeUserLibrary, .typeCloudShared, .typeiTunesSynced]

        return PHAsset.fetchAssets(in: collection, options: fetchOptions)
    }
}
