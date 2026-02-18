//
//  AnalyticsEntity.swift
//  PhotoReviewApp
//
//  Created by Muhammad Abdul Fattah on 07/02/25.
//
import CoreData

@objc(AnalyticsEntity)
class AnalyticsEntity: NSManagedObject {
    @NSManaged var totalStorageSaved: Int64
    @NSManaged var currentStreak: Int64
    @NSManaged var totalReviewed: Int64
    @NSManaged var totalDeleted: Int64
    @NSManaged var totalBookmarked: Int64

    @nonobjc class func fetchRequest() -> NSFetchRequest<AnalyticsEntity> {
        NSFetchRequest<AnalyticsEntity>(entityName: "AnalyticsEntity")
    }
}

