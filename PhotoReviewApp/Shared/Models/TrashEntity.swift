
//  TrashEntity.swift
//  PhotoReviewApp
//
//  Created by Muhammad Abdul Fattah on 07/02/25.

import CoreData

@objc(TrashEntity)
class TrashEntity: NSManagedObject {
    @NSManaged var assetIdentifier: String
    @NSManaged var dateDeleted: Date
    @NSManaged var id: UUID

    @nonobjc class func fetchRequest() -> NSFetchRequest<TrashEntity> {
        NSFetchRequest<TrashEntity>(entityName: "TrashEntity")
    }
}
