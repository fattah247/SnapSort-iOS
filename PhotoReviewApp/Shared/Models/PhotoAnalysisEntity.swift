//
//  PhotoAnalysisEntity.swift
//  PhotoReviewApp
//
//  CoreData entity for caching photo analysis results
//

import CoreData

@objc(PhotoAnalysisEntity)
class PhotoAnalysisEntity: NSManagedObject {
    @NSManaged var assetIdentifier: String
    @NSManaged var analysisDate: Date?
    @NSManaged var categories: NSArray?
    @NSManaged var blurScore: Float
    @NSManaged var brightnessScore: Float
    @NSManaged var featurePrintData: Data?
    @NSManaged var sceneLabels: NSArray?
    @NSManaged var hasQRCode: Bool
    @NSManaged var libraryModDate: Date?

    @nonobjc class func fetchRequest() -> NSFetchRequest<PhotoAnalysisEntity> {
        NSFetchRequest<PhotoAnalysisEntity>(entityName: "PhotoAnalysisEntity")
    }

    /// Converts stored category strings back to SmartCategory set
    var smartCategories: Set<SmartCategory> {
        guard let stored = categories as? [String] else { return [] }
        return Set(stored.compactMap { SmartCategory(rawValue: $0) })
    }

    /// Converts stored scene labels back to string array
    var sceneLabelsArray: [String] {
        (sceneLabels as? [String]) ?? []
    }

    /// Converts this entity to a PhotoAnalysisResult value type
    func toResult() -> PhotoAnalysisResult {
        PhotoAnalysisResult(
            assetIdentifier: assetIdentifier,
            categories: smartCategories,
            blurScore: blurScore,
            brightnessScore: brightnessScore,
            hasQRCode: hasQRCode,
            sceneLabels: sceneLabelsArray,
            featurePrintData: featurePrintData,
            analysisDate: analysisDate ?? Date()
        )
    }

    /// Populates this entity from a PhotoAnalysisResult
    func populate(from result: PhotoAnalysisResult) {
        assetIdentifier = result.assetIdentifier
        analysisDate = result.analysisDate
        categories = result.categories.map { $0.rawValue } as NSArray
        blurScore = result.blurScore
        brightnessScore = result.brightnessScore
        featurePrintData = result.featurePrintData
        sceneLabels = result.sceneLabels as NSArray
        hasQRCode = result.hasQRCode
    }
}
