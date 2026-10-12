//
//  BookmarkEntity.swift
//  SnapSort
//
//  Created by Muhammad Abdul Fattah on 07/02/25.
//
import CoreData

@objc(BookmarkEntity)
class BookmarkEntity: NSManagedObject {
    // Optional to match the model — avoids crashing on rows with missing values
    @NSManaged var assetIdentifier: String?
    @NSManaged var dateAdded: Date?
    @NSManaged var id: UUID?

    @nonobjc class func fetchRequest() -> NSFetchRequest<BookmarkEntity> {
        NSFetchRequest<BookmarkEntity>(entityName: "BookmarkEntity")
    }
}
