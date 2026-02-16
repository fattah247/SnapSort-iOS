//
//  AppColors.swift
//  PhotoReviewApp
//
//  Design System - Color Palette
//

import SwiftUI

enum AppColors {
    // MARK: - Primary Colors
    static let primary = Color(red: 0.4, green: 0.45, blue: 0.95) // Soft Indigo
    static let primaryLight = Color(red: 0.55, green: 0.6, blue: 1.0)
    static let primaryDark = Color(red: 0.3, green: 0.35, blue: 0.85)

    // MARK: - Semantic Colors
    static let success = Color(red: 0.2, green: 0.75, blue: 0.7) // Soft Teal
    static let successLight = Color(red: 0.3, green: 0.85, blue: 0.8)

    static let warning = Color(red: 0.95, green: 0.7, blue: 0.3) // Soft Amber
    static let warningLight = Color(red: 1.0, green: 0.8, blue: 0.4)

    static let danger = Color(red: 0.95, green: 0.45, blue: 0.45) // Soft Coral
    static let dangerLight = Color(red: 1.0, green: 0.6, blue: 0.6)

    // MARK: - Accent Colors
    static let bookmark = Color(red: 0.3, green: 0.75, blue: 0.55) // Green for bookmarks
    static let delete = Color(red: 0.95, green: 0.4, blue: 0.4) // Red for delete
    static let streak = Color(red: 1.0, green: 0.6, blue: 0.2) // Orange for streak

    // MARK: - Gradients
    static let primaryGradient = LinearGradient(
        colors: [primaryLight, primary],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let successGradient = LinearGradient(
        colors: [successLight, success],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let bookmarkGradient = LinearGradient(
        colors: [Color(red: 0.4, green: 0.85, blue: 0.65), bookmark],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let deleteGradient = LinearGradient(
        colors: [dangerLight, danger],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let streakGradient = LinearGradient(
        colors: [Color(red: 1.0, green: 0.75, blue: 0.35), streak],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    // MARK: - Dashboard Gradients
    static let storageGradient = LinearGradient(
        colors: [Color(red: 0.5, green: 0.6, blue: 1.0), Color(red: 0.6, green: 0.4, blue: 0.9)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let reviewedGradient = LinearGradient(
        colors: [Color(red: 0.4, green: 0.8, blue: 0.8), Color(red: 0.3, green: 0.65, blue: 0.7)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let deletedGradient = LinearGradient(
        colors: [Color(red: 1.0, green: 0.65, blue: 0.5), Color(red: 0.9, green: 0.45, blue: 0.4)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let bookmarkedGradient = LinearGradient(
        colors: [Color(red: 0.5, green: 0.9, blue: 0.7), Color(red: 0.3, green: 0.75, blue: 0.55)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    // MARK: - Background Colors
    static let cardBackground = Color(.systemBackground)
    static let groupedBackground = Color(.systemGroupedBackground)
    static let secondaryBackground = Color(.secondarySystemGroupedBackground)

    // MARK: - Text Colors
    static let textPrimary = Color(.label)
    static let textSecondary = Color(.secondaryLabel)
    static let textTertiary = Color(.tertiaryLabel)

    // MARK: - Overlay Colors
    static func overlay(for direction: SwipeDirection) -> Color {
        switch direction {
        case .left:
            return danger.opacity(0.3)
        case .right:
            return bookmark.opacity(0.3)
        }
    }
}

// MARK: - Color Extensions
extension Color {
    static let appPrimary = AppColors.primary
    static let appSuccess = AppColors.success
    static let appWarning = AppColors.warning
    static let appDanger = AppColors.danger
}
