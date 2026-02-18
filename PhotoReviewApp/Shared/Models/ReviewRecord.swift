//
//  ReviewRecord.swift
//  PhotoReviewApp
//
//  Created by Muhammad Abdul Fattah on 07/02/25.
//
import CoreData

@objc(ReviewRecord)
class ReviewRecord: NSManagedObject {
    @NSManaged var assetIdentifier: String
    @NSManaged var reviewDate: Date
    @NSManaged var id: UUID
    @NSManaged var userAction: String
}
