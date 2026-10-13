//
//  AppSpacing.swift
//  SnapSort
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

    // MARK: - Corner Radius
    static let radiusSmall: CGFloat = 10
    static let radiusMedium: CGFloat = 18
    static let radiusLarge: CGFloat = 26

    // MARK: - Grid
    static let gridSpacing: CGFloat = 3
}

// MARK: - View Extensions
extension View {
    /// Soft "paper" card on the oat background.
    func cardStyle() -> some View {
        self
            .padding(AppSpacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                AppColors.cardBackground,
                in: RoundedRectangle(cornerRadius: AppSpacing.radiusMedium, style: .continuous)
            )
            .shadow(color: Color.black.opacity(0.04), radius: 8, y: 3)
    }

    /// Small rounded-square tile behind an SF Symbol, like Settings icons.
    func iconTile(_ color: Color, size: CGFloat = 30, foreground: Color = .white) -> some View {
        self
            .font(.system(size: size * 0.5, weight: .semibold))
            .foregroundStyle(foreground)
            .frame(width: size, height: size)
            .background(color, in: RoundedRectangle(cornerRadius: size * 0.3, style: .continuous))
    }
}

// MARK: - Chunky Button

/// Tactile, slightly 3D button: a darker "lip" sits under the face and the
/// face sinks into it when pressed.
struct ChunkyButtonStyle: ButtonStyle {
    var fill: Color = AppColors.brand
    var foreground: Color = .white
    var shape: Shape = .capsule
    /// A soft tap as the button sinks, so it feels like the press it looks like
    var pressFeedback = true

    enum Shape {
        case capsule
        case circle
    }

    func makeBody(configuration: Configuration) -> some View {
        ChunkyButtonBody(
            configuration: configuration,
            fill: fill,
            foreground: foreground,
            shape: shape,
            pressFeedback: pressFeedback
        )
    }
}

private struct ChunkyButtonBody: View {
    let configuration: ButtonStyleConfiguration
    let fill: Color
    let foreground: Color
    let shape: ChunkyButtonStyle.Shape
    let pressFeedback: Bool

    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.haptics) private var haptics
    private let lip: CGFloat = 4

    var body: some View {
        let pressed = configuration.isPressed
        configuration.label
            .foregroundStyle(foreground)
            .background { face(fill) }
            .background {
                // The lip: same color, a shade darker
                face(fill).overlay { face(.black.opacity(0.2)) }
                    .offset(y: pressed ? 1 : lip)
            }
            .offset(y: pressed ? lip - 1 : 0)
            .opacity(isEnabled ? 1 : 0.45)
            .saturation(isEnabled ? 1 : 0.3)
            .padding(.bottom, lip)
            .animation(.spring(response: 0.18, dampingFraction: 0.6), value: pressed)
            .onChange(of: pressed) { _, isPressed in
                // On touch-down, the same moment the button visibly sinks
                if isPressed, pressFeedback, isEnabled {
                    haptics?.play(.press)
                }
            }
    }

    @ViewBuilder
    private func face(_ color: Color) -> some View {
        switch shape {
        case .capsule: Capsule().fill(color)
        case .circle: Circle().fill(color)
        }
    }
}

extension ButtonStyle where Self == ChunkyButtonStyle {
    static var chunky: ChunkyButtonStyle { ChunkyButtonStyle() }

    static func chunky(_ fill: Color, foreground: Color = .white) -> ChunkyButtonStyle {
        ChunkyButtonStyle(fill: fill, foreground: foreground)
    }
}

/// Full-width label for chunky buttons
struct ChunkyLabel: View {
    let title: String
    var systemImage: String?

    var body: some View {
        HStack(spacing: AppSpacing.xs) {
            if let systemImage {
                Image(systemName: systemImage)
            }
            Text(title)
        }
        .font(.headline)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 15)
    }
}
