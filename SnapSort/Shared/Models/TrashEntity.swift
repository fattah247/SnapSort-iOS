
//  TrashEntity.swift
//  SnapSort
//
//  Created by Muhammad Abdul Fattah on 07/02/25.

import CoreData

@objc(TrashEntity)
class TrashEntity: NSManagedObject {
    // Optional to match the model — avoids crashing on rows with missing values
    @NSManaged var assetIdentifier: String?
    @NSManaged var dateDeleted: Date?
    @NSManaged var id: UUID?

    @nonobjc class func fetchRequest() -> NSFetchRequest<TrashEntity> {
        NSFetchRequest<TrashEntity>(entityName: "TrashEntity")
    }
}
