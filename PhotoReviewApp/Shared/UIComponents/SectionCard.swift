//
//  SectionCard.swift
//  PhotoReviewApp
//
//  Created by Muhammad Abdul Fattah on 17/06/25.
//

import SwiftUI

/// A styled "card" container for a settings section—with a header bar and content area.
struct SectionCard<Content: View>: View {
    let title: String
    let icon: String
    let color: Color
    let content: () -> Content

    @State private var isAppearing = false

    init(
        title: String,
        icon: String,
        color: Color,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.icon = icon
        self.color = color
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(spacing: AppSpacing.sm) {
                ZStack {
                    RoundedRectangle(cornerRadius: AppSpacing.radiusSmall, style: .continuous)
                        .fill(color.opacity(0.12))
                        .frame(width: 32, height: 32)

                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(color)
                }
                .accessibilityHidden(true)

                Text(title)
                    .font(AppTypography.headlineSmall)
                    .foregroundColor(AppColors.textPrimary)

                Spacer()
            }
            .padding(AppSpacing.md)
            .background(AppColors.secondaryBackground)

            // Content
            content()
                .padding(AppSpacing.md)
                .background(AppColors.cardBackground)
        }
        .background(AppColors.secondaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.radiusMedium, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppSpacing.radiusMedium, style: .continuous)
                .stroke(Color.primary.opacity(0.06), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
        .opacity(isAppearing ? 1 : 0)
        .offset(y: isAppearing ? 0 : 10)
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                isAppearing = true
            }
        }
    }
}
