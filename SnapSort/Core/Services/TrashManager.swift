//
//  TrashManager.swift
//  SnapSort
//
//  Created by Muhammad Abdul Fattah on 03/02/25.
//

import CoreData
import Photos
import SwiftUI
import OSLog

@MainActor
protocol TrashManagerProtocol: ObservableObject {
    var trashedAssets: [PHAsset] { get }
    func addToTrash(assetIdentifier: String)
    func addToTrash(assetIdentifiers: [String])
    func restoreFromTrash(assetIdentifier: String)
    func restoreFromTrash(assetIdentifiers: [String])
    func restoreAll()
    func deletePermanently(assetIdentifiers: [String]) async throws
    func emptyTrash() async throws
}

/// Holds photos the user swiped away until they confirm deletion.
///
/// Swiping only records the photo locally — the Photos library is untouched
/// until `deletePermanently` / `emptyTrash`, which hands the whole batch to
/// PhotoKit in one request (one system prompt; items go to Recently Deleted).
@MainActor
final class CoreDataTrashManager: NSObject, ObservableObject, TrashManagerProtocol {
    // MARK: - Published state
    /// Trashed assets, most recently trashed first
    @Published private(set) var trashedAssets: [PHAsset] = []

    // MARK: - Dependencies
    private let context: NSManagedObjectContext
    private let photoService: any PhotoLibraryServiceProtocol
    /// Off in tests: no PhotoKit lookups, so entries aren't pruned as missing
    private let syncsWithLibrary: Bool
    private var isObservingLibrary = false
    private var accessObserver: NSObjectProtocol?

    // MARK: - Init / Deinit
    init(
        context: NSManagedObjectContext,
        photoService: any PhotoLibraryServiceProtocol,
        syncsWithLibrary: Bool = true
    ) {
        self.context = context
        self.photoService = photoService
        self.syncsWithLibrary = syncsWithLibrary
        super.init()
        guard syncsWithLibrary else { return }
        // Touching PhotoKit before access is granted would pop the system
        // prompt at launch, ahead of onboarding's explanation
        if PhotoLibraryAccess.isGranted {
            startObservingLibrary()
        } else {
            accessObserver = NotificationCenter.default.addObserver(
                forName: .photoLibraryAccessGranted, object: nil, queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated { self?.startObservingLibrary() }
            }
        }
    }

    deinit {
        if isObservingLibrary {
            PHPhotoLibrary.shared().unregisterChangeObserver(self)
        }
        if let accessObserver {
            NotificationCenter.default.removeObserver(accessObserver)
        }
    }

    private func startObservingLibrary() {
        guard !isObservingLibrary else { return }
        isObservingLibrary = true
        // Keep in sync when photos are deleted outside the app
        PHPhotoLibrary.shared().register(self)
        refresh()
    }

    // MARK: - TrashManagerProtocol

    func addToTrash(assetIdentifier: String) {
        addToTrash(assetIdentifiers: [assetIdentifier])
    }

    func addToTrash(assetIdentifiers: [String]) {
        let existing = Set(fetchEntities().compactMap(\.assetIdentifier))
        let now = Date()
        for identifier in assetIdentifiers where !existing.contains(identifier) {
            let entity = TrashEntity(context: context)
            entity.id = UUID()
            entity.assetIdentifier = identifier
            entity.dateDeleted = now
        }
        saveContext()
        refresh()
    }

    func restoreFromTrash(assetIdentifier: String) {
        removeEntities(for: [assetIdentifier])
    }

    func restoreFromTrash(assetIdentifiers: [String]) {
        removeEntities(for: assetIdentifiers)
    }

    func restoreAll() {
        fetchEntities().forEach(context.delete)
        saveContext()
        refresh()
    }

    func deletePermanently(assetIdentifiers: [String]) async throws {
        let assets = trashedAssets.filter { assetIdentifiers.contains($0.localIdentifier) }
        guard !assets.isEmpty else { return }
        // Throws if the user taps "Don't Allow" — entries stay in the trash
        try await photoService.deleteAssets(assets)
        removeEntities(for: assets.map(\.localIdentifier))
    }

    func emptyTrash() async throws {
        try await deletePermanently(assetIdentifiers: trashedAssets.map(\.localIdentifier))
    }

    /// Identifiers saved in the trash, readable before photo access is granted
    var storedIdentifiers: [String] {
        fetchEntities().compactMap(\.assetIdentifier)
    }

    // MARK: - Helpers

    /// Re-reads trashed identifiers and resolves them to assets, dropping any
    /// entries whose photo no longer exists in the library.
    func refresh() {
        guard syncsWithLibrary, PhotoLibraryAccess.isGranted else { return }
        let entities = fetchEntities()
        let identifiers = entities.compactMap(\.assetIdentifier)
        guard !identifiers.isEmpty else {
            trashedAssets = []
            return
        }

        let result = PHAsset.fetchAssets(withLocalIdentifiers: identifiers, options: nil)
        var assetsById = [String: PHAsset]()
        result.enumerateObjects { asset, _, _ in
            assetsById[asset.localIdentifier] = asset
        }

        // Prune orphans (deleted from Photos directly)
        let orphans = entities.filter { assetsById[$0.assetIdentifier ?? ""] == nil }
        if !orphans.isEmpty {
            orphans.forEach(context.delete)
            saveContext()
        }

        trashedAssets = identifiers.compactMap { assetsById[$0] }
    }

    private func fetchEntities() -> [TrashEntity] {
        let request: NSFetchRequest<TrashEntity> = TrashEntity.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "dateDeleted", ascending: false)]
        do {
            return try context.fetch(request)
        } catch {
            AppLogger.coreData.error("Error fetching trash: \(error.localizedDescription, privacy: .public)")
            return []
        }
    }

    private func removeEntities(for identifiers: [String]) {
        let request: NSFetchRequest<TrashEntity> = TrashEntity.fetchRequest()
        request.predicate = NSPredicate(format: "assetIdentifier IN %@", identifiers)
        do {
            try context.fetch(request).forEach(context.delete)
            saveContext()
            refresh()
        } catch {
            AppLogger.coreData.error("Error restoring from trash: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func saveContext() {
        guard context.hasChanges else { return }
        do {
            try context.save()
        } catch {
            AppLogger.coreData.error("Error saving CoreData context in TrashManager: \(error.localizedDescription, privacy: .public)")
        }
    }
}

// MARK: - PHPhotoLibraryChangeObserver

extension CoreDataTrashManager: PHPhotoLibraryChangeObserver {
    nonisolated func photoLibraryDidChange(_ changeInstance: PHChange) {
        Task { @MainActor in self.refresh() }
    }
}
