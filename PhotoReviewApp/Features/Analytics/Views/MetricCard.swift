//
//  MetricCardView.swift
//  PhotoReviewApp
//
//  Created by Muhammad Abdul Fattah on 07/02/25.
//
import SwiftUI

struct MetricCard: View {
    let title: String
    let icon: String
    let value: String
    let gradient: LinearGradient

    @State private var isPressed = false

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            // Icon row
            HStack {
                ZStack {
                    Circle()
                        .fill(.white.opacity(0.2))
                        .frame(width: 40, height: 40)

                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                }

                Spacer()
            }

            Spacer()

            // Value and title
            VStack(alignment: .leading, spacing: 4) {
                Text(value)
                    .font(AppTypography.numberMedium)
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                Text(title)
                    .font(AppTypography.labelSmall)
                    .foregroundColor(.white.opacity(0.8))
            }
        }
        .padding(AppSpacing.md)
        .frame(maxWidth: .infinity, minHeight: 130, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: AppSpacing.radiusLarge, style: .continuous)
                .fill(gradient)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppSpacing.radiusLarge, style: .continuous)
                .stroke(.white.opacity(0.15), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.15), radius: 10, x: 0, y: 4)
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isPressed)
    }
}

struct MetricBadge: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: AppSpacing.xs) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(color)
                .padding(AppSpacing.sm)
                .background(Circle().fill(color.opacity(0.12)))

            Text(value)
                .font(AppTypography.numberSmall)
                .foregroundColor(AppColors.textPrimary)

            Text(title)
                .font(AppTypography.caption)
                .foregroundColor(AppColors.textSecondary)
        }
        .padding(AppSpacing.sm)
        .frame(maxWidth: .infinity)
        .background(AppColors.secondaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.radiusMedium, style: .continuous))
    }
}

// MARK: - Empty State Views
struct EmptyBookmarksView: View {
    var onStartReviewing: (() -> Void)?

    var body: some View {
        VStack(spacing: AppSpacing.lg) {
            ZStack {
                Circle()
                    .fill(AppColors.bookmark.opacity(0.12))
                    .frame(width: 100, height: 100)

                Image(systemName: "bookmark.slash")
                    .font(.system(size: 44))
                    .foregroundColor(AppColors.bookmark.opacity(0.6))
            }

            VStack(spacing: AppSpacing.xs) {
                Text("No Bookmarks Yet")
                    .font(AppTypography.headlineMedium)
                    .foregroundColor(AppColors.textPrimary)

                Text("Photos you bookmark while reviewing will appear here")
                    .font(AppTypography.bodySmall)
                    .foregroundColor(AppColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, AppSpacing.xl)
            }

            if let action = onStartReviewing {
                Button(action: action) {
                    HStack(spacing: AppSpacing.xs) {
                        Image(systemName: "photo.stack")
                        Text("Start Reviewing")
                    }
                    .font(AppTypography.button)
                    .foregroundColor(.white)
                    .padding(.horizontal, AppSpacing.lg)
                    .padding(.vertical, AppSpacing.sm)
                    .background(AppColors.bookmarkGradient)
                    .clipShape(Capsule())
                }
                .padding(.top, AppSpacing.sm)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct EmptyTrashView: View {
    var body: some View {
        VStack(spacing: AppSpacing.lg) {
            ZStack {
                Circle()
                    .fill(AppColors.success.opacity(0.12))
                    .frame(width: 100, height: 100)

                Image(systemName: "trash.slash")
                    .font(.system(size: 44))
                    .foregroundColor(AppColors.success.opacity(0.6))
            }

            VStack(spacing: AppSpacing.xs) {
                Text("Trash is Empty")
                    .font(AppTypography.headlineMedium)
                    .foregroundColor(AppColors.textPrimary)

                Text("Photos you delete will appear here for 30 days before being permanently removed")
                    .font(AppTypography.bodySmall)
                    .foregroundColor(AppColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, AppSpacing.xl)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
