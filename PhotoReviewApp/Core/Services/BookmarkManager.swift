//
//  BookmarkManager.swift
//  PhotoReviewApp
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
    func isBookmarked(assetIdentifier: String) -> Bool
}

final class CoreDataBookmarkManager: ObservableObject, BookmarkManagerProtocol {
    private let context: NSManagedObjectContext
    private let photoService: any PhotoLibraryServiceProtocol
    
    @Published var bookmarkedAssets: [PHAsset] = []
    
    init(context: NSManagedObjectContext, photoService: any PhotoLibraryServiceProtocol) {
        self.context = context
        self.photoService = photoService
        refreshBookmarks()
    }
    
    func toggleBookmark(assetIdentifier: String) {
        let request: NSFetchRequest<BookmarkEntity> = BookmarkEntity.fetchRequest()
        request.predicate = NSPredicate(format: "assetIdentifier == %@", assetIdentifier)

        do {
            if let existing = try context.fetch(request).first {
                context.delete(existing)
            } else {
                let newBookmark = BookmarkEntity(context: context)
                newBookmark.id = UUID()
                newBookmark.assetIdentifier = assetIdentifier
                newBookmark.dateAdded = Date()
            }
            try context.save()
            refreshBookmarks()
        } catch {
            AppLogger.coreData.error("Error toggling bookmark: \(error.localizedDescription, privacy: .public)")
        }
    }

    
    func isBookmarked(assetIdentifier: String) -> Bool {
        bookmarkedAssets.contains { $0.localIdentifier == assetIdentifier }
    }
    
    private func refreshBookmarks() {
        let request: NSFetchRequest<BookmarkEntity> = BookmarkEntity.fetchRequest()
        do {
            let identifiers = try context.fetch(request).compactMap { $0.assetIdentifier }
            let result = PHAsset.fetchAssets(withLocalIdentifiers: identifiers, options: nil)
            bookmarkedAssets = result.objects(at: IndexSet(0..<result.count))
        } catch {
            AppLogger.coreData.error("Error fetching bookmarks: \(error.localizedDescription, privacy: .public)")
        }
    }
}
