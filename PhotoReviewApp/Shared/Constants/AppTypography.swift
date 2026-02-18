//
//  AppTypography.swift
//  PhotoReviewApp
//
//  Design System - Typography Scale
//

import SwiftUI

enum AppTypography {
    // MARK: - Display
    static let displayLarge = Font.system(size: 34, weight: .bold, design: .rounded)
    static let displayMedium = Font.system(size: 28, weight: .bold, design: .rounded)
    static let displaySmall = Font.system(size: 24, weight: .semibold, design: .rounded)

    // MARK: - Headlines
    static let headlineLarge = Font.system(size: 22, weight: .semibold, design: .rounded)
    static let headlineMedium = Font.system(size: 18, weight: .semibold, design: .rounded)
    static let headlineSmall = Font.system(size: 16, weight: .semibold, design: .rounded)

    // MARK: - Body
    static let bodyLarge = Font.system(size: 17, weight: .regular, design: .default)
    static let bodyMedium = Font.system(size: 15, weight: .regular, design: .default)
    static let bodySmall = Font.system(size: 13, weight: .regular, design: .default)

    // MARK: - Labels
    static let labelLarge = Font.system(size: 14, weight: .medium, design: .default)
    static let labelMedium = Font.system(size: 12, weight: .medium, design: .default)
    static let labelSmall = Font.system(size: 11, weight: .medium, design: .default)

    // MARK: - Captions
    static let caption = Font.system(size: 12, weight: .regular, design: .default)
    static let captionBold = Font.system(size: 12, weight: .semibold, design: .default)

    // MARK: - Numbers
    static let numberLarge = Font.system(size: 32, weight: .bold, design: .rounded).monospacedDigit()
    static let numberMedium = Font.system(size: 24, weight: .semibold, design: .rounded).monospacedDigit()
    static let numberSmall = Font.system(size: 18, weight: .medium, design: .rounded).monospacedDigit()

    // MARK: - Special
    static let button = Font.system(size: 16, weight: .semibold, design: .rounded)
    static let badge = Font.system(size: 10, weight: .bold, design: .rounded)
}

// MARK: - Font Extensions
extension Font {
    static let appDisplayLarge = AppTypography.displayLarge
    static let appDisplayMedium = AppTypography.displayMedium
    static let appHeadline = AppTypography.headlineMedium
    static let appBody = AppTypography.bodyMedium
    static let appCaption = AppTypography.caption
    static let appNumber = AppTypography.numberMedium
}

// MARK: - View Modifier for Typography
struct AppTextStyle: ViewModifier {
    let font: Font
    let color: Color

    func body(content: Content) -> some View {
        content
            .font(font)
            .foregroundColor(color)
    }
}

extension View {
    func appTextStyle(_ font: Font, color: Color = AppColors.textPrimary) -> some View {
        modifier(AppTextStyle(font: font, color: color))
    }
}
