//
//  SmartCategory.swift
//  PhotoReviewApp
//
//  Smart AI-powered photo categories using Vision & CoreImage
//

import SwiftUI

// MARK: - Smart Category

enum SmartCategory: String, CaseIterable, Identifiable {
    case people = "People"
    case scenery = "Scenery"
    case blurry = "Blurry"
    case probablyUnwanted = "Probably Unwanted"
    case qrCodes = "QR Codes"
    case duplicates = "Duplicates"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .people: return "person.2.fill"
        case .scenery: return "mountain.2.fill"
        case .blurry: return "aqi.low"
        case .probablyUnwanted: return "exclamationmark.triangle.fill"
        case .qrCodes: return "qrcode"
        case .duplicates: return "doc.on.doc.fill"
        }
    }

    var color: Color {
        switch self {
        case .people: return AppColors.primary
        case .scenery: return AppColors.success
        case .blurry: return AppColors.warning
        case .probablyUnwanted: return AppColors.danger
        case .qrCodes: return .purple
        case .duplicates: return .cyan
        }
    }

    var description: String {
        switch self {
        case .people: return "Photos grouped by person"
        case .scenery: return "Landscapes and nature shots"
        case .blurry: return "Out-of-focus or shaky photos"
        case .probablyUnwanted: return "Too dark, overexposed, or low quality"
        case .qrCodes: return "Screenshots and photos with QR codes"
        case .duplicates: return "Similar or duplicate photos"
        }
    }

    /// Whether this category requires Vision/CoreImage analysis (vs. metadata-only)
    var requiresAnalysis: Bool {
        switch self {
        case .people: return false // Uses PHCollectionList People albums
        default: return true
        }
    }
}

// MARK: - Category Selection

/// Unified category type that bridges library-based and smart categories
enum CategorySelection: Equatable, Hashable {
    case library(PhotoCategory)
    case smart(SmartCategory)
    case person(id: String, name: String)

    var displayName: String {
        switch self {
        case .library(let category): return category.rawValue
        case .smart(let category): return category.rawValue
        case .person(_, let name): return name
        }
    }

    var icon: String {
        switch self {
        case .library(let category): return category.icon
        case .smart(let category): return category.icon
        case .person: return "person.crop.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .library(let category): return category.color
        case .smart(let category): return category.color
        case .person: return AppColors.primary
        }
    }
}

// MARK: - Review Mode

/// Tracks whether the user is browsing library categories or smart analysis
enum ReviewMode: String, CaseIterable {
    case library = "Library"
    case smart = "Smart"
}
