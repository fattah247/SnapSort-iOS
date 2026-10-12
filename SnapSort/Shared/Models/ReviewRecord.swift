//
//  ReviewRecord.swift
//  SnapSort
//
//  Created by Muhammad Abdul Fattah on 07/02/25.
//
import CoreData

/// One row per review decision — drives the weekly chart and day streak.
@objc(ReviewRecord)
class ReviewRecord: NSManagedObject {
    @NSManaged var assetIdentifier: String?
    @NSManaged var reviewDate: Date?
    // The model stores `id` as a String
    @NSManaged var id: String?
    @NSManaged var userAction: String?

    @nonobjc class func fetchRequest() -> NSFetchRequest<ReviewRecord> {
        NSFetchRequest<ReviewRecord>(entityName: "ReviewRecord")
    }
}

/// The decision a review record captures
enum ReviewAction: String {
    case bookmark
    case delete
}
