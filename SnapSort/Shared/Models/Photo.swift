//
//  Photo.swift
//  SnapSort
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
    /// Non-nil for videos
    var duration: TimeInterval? = nil

    var isVideo: Bool { duration != nil }

    var smartCategories: Set<SmartCategory> {
        analysisResult?.categories ?? []
    }

    /// "1:05" or "1:02:10"
    var durationText: String? {
        guard let duration else { return nil }
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = duration >= 3600 ? [.hour, .minute, .second] : [.minute, .second]
        formatter.zeroFormattingBehavior = .pad
        return formatter.string(from: duration)
    }

    static func == (lhs: Photo, rhs: Photo) -> Bool {
        lhs.id == rhs.id
            && lhs.creationDate == rhs.creationDate
            && lhs.fileSize == rhs.fileSize
            // Compare image identity so SwiftUI redraws when a sharper image arrives
            && lhs.image === rhs.image
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

    var displayName: String {
        switch self {
        case .daily: return "Daily"
        case .weekly: return "Weekly"
        case .monthly: return "Monthly"
        case .never: return "Never"
        }
    }
}

enum PhotoSortOption: String, CaseIterable {
    case random, newestFirst, oldestFirst

    var displayName: String {
        switch self {
        case .random: return "Shuffled"
        case .newestFirst: return "Newest First"
        case .oldestFirst: return "Oldest First"
        }
    }

    var sortDescriptors: [NSSortDescriptor] {
        switch self {
        case .newestFirst: return [NSSortDescriptor(key: "creationDate", ascending: false)]
        case .oldestFirst: return [NSSortDescriptor(key: "creationDate", ascending: true)]
        case .random: return []
        }
    }
}

/// Raw values match `Calendar` weekday numbering (Sunday = 1)
enum Weekday: Int, CaseIterable, Identifiable {
    case sun = 1, mon, tue, wed, thu, fri, sat

    var id: Int { rawValue }

    /// Localized, e.g. "Mon"
    var shortName: String {
        Calendar.current.shortWeekdaySymbols[rawValue - 1]
    }

    /// Localized, e.g. "M"
    var initial: String {
        Calendar.current.veryShortWeekdaySymbols[rawValue - 1]
    }

    /// Weekdays ordered by the user's first day of the week
    static var localeOrdered: [Weekday] {
        let first = Calendar.current.firstWeekday
        return allCases.sorted {
            ($0.rawValue - first + 7) % 7 < ($1.rawValue - first + 7) % 7
        }
    }
}
