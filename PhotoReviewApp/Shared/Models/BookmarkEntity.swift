//
//  BookmarkEntity.swift
//  PhotoReviewApp
//
//  Created by Muhammad Abdul Fattah on 07/02/25.
//
import CoreData

@objc(BookmarkEntity)
class BookmarkEntity: NSManagedObject {
    @NSManaged var assetIdentifier: String
    @NSManaged var dateAdded: Date
    @NSManaged var id: UUID

    @nonobjc class func fetchRequest() -> NSFetchRequest<BookmarkEntity> {
        NSFetchRequest<BookmarkEntity>(entityName: "BookmarkEntity")
    }
}

