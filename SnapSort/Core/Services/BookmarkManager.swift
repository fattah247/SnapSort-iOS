//
//  BookmarkManager.swift
//  SnapSort
//
//  Created by Muhammad Abdul Fattah on 03/02/25.
//
import CoreData
import Photos
import SwiftUI
import OSLog

protocol BookmarkManagerProtocol: ObservableObject {
    var bookmarkedAssets: [PHAsset] { get }
    func toggleBookmark(assetIdentifier: String)
    func setBookmarked(_ isBookmarked: Bool, assetIdentifier: String)
    func isBookmarked(assetIdentifier: String) -> Bool
}

final class CoreDataBookmarkManager: ObservableObject, BookmarkManagerProtocol {
    private let context: NSManagedObjectContext
    private let photoService: any PhotoLibraryServiceProtocol

    /// Bookmarked assets, most recently bookmarked first
    @Published private(set) var bookmarkedAssets: [PHAsset] = []

    private var accessObserver: NSObjectProtocol?

    init(context: NSManagedObjectContext, photoService: any PhotoLibraryServiceProtocol) {
        self.context = context
        self.photoService = photoService
        refreshBookmarks()
        // Bookmarks can't be resolved to assets until access is granted
        accessObserver = NotificationCenter.default.addObserver(
            forName: .photoLibraryAccessGranted, object: nil, queue: .main
        ) { [weak self] _ in
            self?.refreshBookmarks()
        }
    }

    deinit {
        if let accessObserver {
            NotificationCenter.default.removeObserver(accessObserver)
        }
    }

    func toggleBookmark(assetIdentifier: String) {
        setBookmarked(!isBookmarked(assetIdentifier: assetIdentifier), assetIdentifier: assetIdentifier)
    }

    func setBookmarked(_ isBookmarked: Bool, assetIdentifier: String) {
        let request: NSFetchRequest<BookmarkEntity> = BookmarkEntity.fetchRequest()
        request.predicate = NSPredicate(format: "assetIdentifier == %@", assetIdentifier)

        do {
            let existing = try context.fetch(request)
            if isBookmarked {
                guard existing.isEmpty else { return }
                let newBookmark = BookmarkEntity(context: context)
                newBookmark.id = UUID()
                newBookmark.assetIdentifier = assetIdentifier
                newBookmark.dateAdded = Date()
            } else {
                guard !existing.isEmpty else { return }
                existing.forEach(context.delete)
            }
            try context.save()
            refreshBookmarks()
        } catch {
            AppLogger.coreData.error("Error updating bookmark: \(error.localizedDescription, privacy: .public)")
        }
    }

    func removeBookmarks(assetIdentifiers: Set<String>) {
        guard !assetIdentifiers.isEmpty else { return }
        let request: NSFetchRequest<BookmarkEntity> = BookmarkEntity.fetchRequest()
        request.predicate = NSPredicate(format: "assetIdentifier IN %@", Array(assetIdentifiers))
        do {
            try context.fetch(request).forEach(context.delete)
            try context.save()
            refreshBookmarks()
        } catch {
            AppLogger.coreData.error("Error removing bookmarks: \(error.localizedDescription, privacy: .public)")
        }
    }

    func isBookmarked(assetIdentifier: String) -> Bool {
        bookmarkedAssets.contains { $0.localIdentifier == assetIdentifier }
    }

    private func refreshBookmarks() {
        // Touching PhotoKit before access is granted pops the system prompt
        guard PhotoLibraryAccess.isGranted else { return }
        let request: NSFetchRequest<BookmarkEntity> = BookmarkEntity.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "dateAdded", ascending: false)]
        do {
            let identifiers = try context.fetch(request).compactMap(\.assetIdentifier)
            let result = PHAsset.fetchAssets(withLocalIdentifiers: identifiers, options: nil)
            var assetsById = [String: PHAsset]()
            result.enumerateObjects { asset, _, _ in
                assetsById[asset.localIdentifier] = asset
            }
            // PhotoKit doesn't preserve identifier order — restore date-added order
            bookmarkedAssets = identifiers.compactMap { assetsById[$0] }
        } catch {
            AppLogger.coreData.error("Error fetching bookmarks: \(error.localizedDescription, privacy: .public)")
        }
    }
}
