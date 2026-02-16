//
//  Photo.swift
//  PhotoReviewApp
//
//  Created by Muhammad Abdul Fattah on 06/02/25.
//
import Foundation
import Photos
import UIKit

struct Photo: Identifiable, Equatable {
    let id: String
    var image: UIImage?
    let creationDate: Date?
    let fileSize: Int64
    var analysisResult: PhotoAnalysisResult?

    var smartCategories: Set<SmartCategory> {
        analysisResult?.categories ?? []
    }

    static func == (lhs: Photo, rhs: Photo) -> Bool {
        lhs.id == rhs.id
            && lhs.creationDate == rhs.creationDate
            && lhs.fileSize == rhs.fileSize
    }
}

// MARK: - Photo Analysis Result

struct PhotoAnalysisResult: Equatable {
    let assetIdentifier: String
    var categories: Set<SmartCategory>
    let blurScore: Float
    let brightnessScore: Float
    let hasQRCode: Bool
    let sceneLabels: [String]
    let featurePrintData: Data?
    let analysisDate: Date

    static func == (lhs: PhotoAnalysisResult, rhs: PhotoAnalysisResult) -> Bool {
        lhs.assetIdentifier == rhs.assetIdentifier
            && lhs.analysisDate == rhs.analysisDate
    }
}

// MARK: - Analysis Progress

struct AnalysisProgress {
    var totalPhotos: Int = 0
    var analyzedPhotos: Int = 0
    var isScanning: Bool = false
    var currentPhase: String = ""

    var progress: Double {
        guard totalPhotos > 0 else { return 0 }
        return Double(analyzedPhotos) / Double(totalPhotos)
    }
}

// Enums.swift
enum RepeatInterval: String, CaseIterable {
    case daily, weekly, monthly, never
}

enum PhotoSortOption: String, CaseIterable {
    case random, newestFirst, oldestFirst
    
    var sortDescriptors: [NSSortDescriptor] {
        switch self {
        case .newestFirst: return [NSSortDescriptor(key: "creationDate", ascending: false)]
        case .oldestFirst: return [NSSortDescriptor(key: "creationDate", ascending: true)]
        case .random: return []
        }
    }
}

enum Weekday: Int, CaseIterable, Identifiable {
    case sun = 1, mon, tue, wed, thu, fri, sat
    
    var id: Int { rawValue }
}

// For nicer display
extension Weekday {
    var shortName: String {
        switch self {
        case .sun: return "Sun"
        case .mon: return "Mon"
        case .tue: return "Tue"
        case .wed: return "Wed"
        case .thu: return "Thu"
        case .fri: return "Fri"
        case .sat: return "Sat"
        }
    }
}
