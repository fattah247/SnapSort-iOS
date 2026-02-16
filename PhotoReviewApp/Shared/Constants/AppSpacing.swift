//
//  AppSpacing.swift
//  PhotoReviewApp
//
//  Design System - Spacing & Layout
//

import SwiftUI

enum AppSpacing {
    // MARK: - Base Spacing Scale
    static let xxs: CGFloat = 4
    static let xs: CGFloat = 8
    static let sm: CGFloat = 12
    static let md: CGFloat = 16
    static let lg: CGFloat = 24
    static let xl: CGFloat = 32
    static let xxl: CGFloat = 48

    // MARK: - Component Specific
    static let cardPadding: CGFloat = 16
    static let sectionSpacing: CGFloat = 24
    static let itemSpacing: CGFloat = 12
    static let iconSize: CGFloat = 24
    static let iconSizeLarge: CGFloat = 32
    static let iconSizeSmall: CGFloat = 20

    // MARK: - Corner Radius
    static let radiusSmall: CGFloat = 8
    static let radiusMedium: CGFloat = 12
    static let radiusLarge: CGFloat = 16
    static let radiusXLarge: CGFloat = 20
    static let radiusRound: CGFloat = 100

    // MARK: - Shadows
    static let shadowSmall = ShadowStyle(
        color: Color.black.opacity(0.08),
        radius: 4,
        x: 0,
        y: 2
    )

    static let shadowMedium = ShadowStyle(
        color: Color.black.opacity(0.12),
        radius: 8,
        x: 0,
        y: 4
    )

    static let shadowLarge = ShadowStyle(
        color: Color.black.opacity(0.16),
        radius: 16,
        x: 0,
        y: 8
    )

    // MARK: - Animation Durations
    static let animationFast: Double = 0.15
    static let animationNormal: Double = 0.3
    static let animationSlow: Double = 0.5

    // MARK: - Grid
    static let gridMinItemSize: CGFloat = 120
    static let gridSpacing: CGFloat = 8
}

// MARK: - Shadow Style
struct ShadowStyle {
    let color: Color
    let radius: CGFloat
    let x: CGFloat
    let y: CGFloat
}

// MARK: - View Extensions
extension View {
    func appShadow(_ style: ShadowStyle) -> some View {
        shadow(color: style.color, radius: style.radius, x: style.x, y: style.y)
    }

    func appCardStyle() -> some View {
        self
            .background(AppColors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppSpacing.radiusMedium, style: .continuous))
            .appShadow(AppSpacing.shadowSmall)
    }

    func appSectionStyle() -> some View {
        self
            .padding(AppSpacing.cardPadding)
            .background(AppColors.secondaryBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppSpacing.radiusMedium, style: .continuous))
    }
}

// MARK: - Animation Helpers
extension Animation {
    static let appSpring = Animation.spring(response: 0.35, dampingFraction: 0.8)
    static let appBouncy = Animation.spring(response: 0.4, dampingFraction: 0.6)
    static let appSmooth = Animation.easeInOut(duration: AppSpacing.animationNormal)
    static let appFast = Animation.easeOut(duration: AppSpacing.animationFast)
}
