//
//  AppColors.swift
//  SnapSort
//
//  Design System - Color Palette
//
//  A warm "picnic" palette: clover, honey, tomato and sky on oat.
//  Every color lives in the asset catalog with dark and Increase Contrast
//  variants, so nothing here needs to branch on appearance.
//

import SwiftUI

enum AppColors {
    // MARK: - Brand
    /// Clover green. Applied app-wide with `.tint`; use this instead of `Color.accentColor`.
    static let brand = Color("AccentColor")

    // MARK: - Actions
    /// Swipe right / bookmark
    static let keep = Color(.honey)
    /// Glyphs and text drawn on top of `keep`
    static let keepInk = Color(.honeyInk)
    /// Swipe left / move to trash
    static let delete = Color(.tomato)

    // MARK: - Accents
    static let streak = Color(.tangerine)
    static let storage = Color(.sky)
    static let people = Color(.plum)

    // MARK: - Surfaces
    /// Warm app background
    static let groupedBackground = Color(.oat)
    /// Cards and list rows
    static let cardBackground = Color(.paper)
    /// Image placeholders and quiet fills
    static let placeholder = Color(.sand)
}
