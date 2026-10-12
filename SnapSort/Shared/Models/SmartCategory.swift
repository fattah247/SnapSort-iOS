//
//  SmartCategory.swift
//  SnapSort
//
//  Photo groups detected on-device with Vision & CoreImage
//

import SwiftUI

// MARK: - Smart Category

enum SmartCategory: String, CaseIterable, Identifiable {
    // Raw values are persisted in the analysis cache — keep them stable
    case duplicates
    case blurry
    case unwanted
    case screenshots
    case documents
    case qrCodes
    case longVideos
    case people
    case pets
    case food
    case scenery

    var id: String { rawValue }

    enum Section: String, CaseIterable {
        case cleanUp = "Clean Up"
        case browse = "Browse"
    }

    var section: Section {
        switch self {
        case .duplicates, .blurry, .unwanted, .screenshots, .documents, .qrCodes, .longVideos:
            return .cleanUp
        case .people, .pets, .food, .scenery:
            return .browse
        }
    }

    var displayName: String {
        switch self {
        case .duplicates: return "Similar Shots"
        case .blurry: return "Blurry"
        case .unwanted: return "Oops Shots"
        case .screenshots: return "Screenshots"
        case .documents: return "Docs & Receipts"
        case .qrCodes: return "QR Codes"
        case .longVideos: return "Long Videos"
        case .people: return "People"
        case .pets: return "Pets"
        case .food: return "Food"
        case .scenery: return "Scenery"
        }
    }

    var description: String {
        switch self {
        case .duplicates: return "Near-identical photos taken together"
        case .blurry: return "Shaky or out of focus"
        case .unwanted: return "Too dark, too bright, or taken by accident"
        case .screenshots: return "Saved from your screen"
        case .documents: return "Paperwork, notes, and receipts"
        case .qrCodes: return "Tickets, menus, and links"
        case .longVideos: return "A minute or longer — the big space hogs"
        case .people: return "Photos with faces"
        case .pets: return "Furry, feathery, and scaly friends"
        case .food: return "Meals, snacks, and treats"
        case .scenery: return "Landscapes, skies, and cityscapes"
        }
    }

    var icon: String {
        switch self {
        case .duplicates: return "square.on.square"
        case .blurry: return "eyeglasses"
        case .unwanted: return "sun.max.trianglebadge.exclamationmark"
        case .screenshots: return "camera.viewfinder"
        case .documents: return "doc.text"
        case .qrCodes: return "qrcode"
        case .longVideos: return "video"
        case .people: return "person.2"
        case .pets: return "pawprint"
        case .food: return "fork.knife"
        case .scenery: return "mountain.2"
        }
    }

    var color: Color {
        switch self {
        case .duplicates: return AppColors.brand
        case .blurry: return AppColors.storage
        case .unwanted: return AppColors.streak
        case .screenshots: return Color(.systemGray)
        case .documents: return AppColors.storage
        case .qrCodes: return Color(.systemGray)
        case .longVideos: return AppColors.delete
        case .people: return AppColors.people
        case .pets: return AppColors.streak
        case .food: return AppColors.delete
        case .scenery: return AppColors.brand
        }
    }

    /// Groups computed from the analysis cache (vs. queried live from PhotoKit)
    var isAnalyzed: Bool {
        self != .longVideos
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
        case .smart(let category): return category.displayName
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

    var isLibrary: Bool {
        if case .library = self { return true }
        return false
    }
}

// MARK: - Review Mode

/// Tracks whether the user is browsing library categories or smart analysis
enum ReviewMode: String, CaseIterable {
    case library = "Library"
    case smart = "Smart"
}
