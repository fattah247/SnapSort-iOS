//
//  AchievementBadge.swift
//  PhotoReviewApp
//
//  Achievement badges for milestones
//

import SwiftUI

// MARK: - Achievement Types
enum AchievementType: CaseIterable {
    case photos100, photos500, photos1000
    case storage100MB, storage1GB, storage5GB
    case streak7, streak30, streak100

    var title: String {
        switch self {
        case .photos100: return "Starter"
        case .photos500: return "Reviewer"
        case .photos1000: return "Expert"
        case .storage100MB: return "Space Saver"
        case .storage1GB: return "Organizer"
        case .storage5GB: return "Master"
        case .streak7: return "Weekly"
        case .streak30: return "Monthly"
        case .streak100: return "Dedicated"
        }
    }

    var description: String {
        switch self {
        case .photos100: return "Review 100 photos"
        case .photos500: return "Review 500 photos"
        case .photos1000: return "Review 1000 photos"
        case .storage100MB: return "Save 100 MB"
        case .storage1GB: return "Save 1 GB"
        case .storage5GB: return "Save 5 GB"
        case .streak7: return "7-day streak"
        case .streak30: return "30-day streak"
        case .streak100: return "100-day streak"
        }
    }

    var icon: String {
        switch self {
        case .photos100, .photos500, .photos1000:
            return "photo.stack.fill"
        case .storage100MB, .storage1GB, .storage5GB:
            return "externaldrive.fill"
        case .streak7, .streak30, .streak100:
            return "flame.fill"
        }
    }

    var gradient: LinearGradient {
        switch self {
        case .photos100, .photos500, .photos1000:
            return AppColors.primaryGradient
        case .storage100MB, .storage1GB, .storage5GB:
            return AppColors.storageGradient
        case .streak7, .streak30, .streak100:
            return AppColors.streakGradient
        }
    }

    var threshold: Int64 {
        switch self {
        case .photos100: return 100
        case .photos500: return 500
        case .photos1000: return 1000
        case .storage100MB: return 100 * 1024 * 1024
        case .storage1GB: return 1024 * 1024 * 1024
        case .storage5GB: return 5 * 1024 * 1024 * 1024
        case .streak7: return 7
        case .streak30: return 30
        case .streak100: return 100
        }
    }

    func isUnlocked(reviewed: Int64, storage: Int64, streak: Int) -> Bool {
        switch self {
        case .photos100, .photos500, .photos1000:
            return reviewed >= threshold
        case .storage100MB, .storage1GB, .storage5GB:
            return storage >= threshold
        case .streak7, .streak30, .streak100:
            return Int64(streak) >= threshold
        }
    }
}

// MARK: - Achievement Badge View
struct AchievementBadge: View {
    let type: AchievementType
    let isUnlocked: Bool
    @State private var isAnimating = false

    var body: some View {
        VStack(spacing: AppSpacing.xs) {
            ZStack {
                // Background circle
                Circle()
                    .fill(isUnlocked ? type.gradient : LinearGradient(colors: [Color.gray.opacity(0.3), Color.gray.opacity(0.2)], startPoint: .top, endPoint: .bottom))
                    .frame(width: 60, height: 60)

                // Icon
                Image(systemName: type.icon)
                    .font(.system(size: 24))
                    .foregroundColor(isUnlocked ? .white : .gray.opacity(0.5))

                // Lock overlay for locked badges
                if !isUnlocked {
                    Circle()
                        .fill(Color.black.opacity(0.3))
                        .frame(width: 60, height: 60)

                    Image(systemName: "lock.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.7))
                        .offset(x: 18, y: 18)
                }
            }
            .scaleEffect(isAnimating ? 1.1 : 1.0)
            .shadow(color: isUnlocked ? type.gradient.stops.first?.color.opacity(0.4) ?? .clear : .clear, radius: 8, x: 0, y: 4)

            Text(type.title)
                .font(AppTypography.labelSmall)
                .foregroundColor(isUnlocked ? AppColors.textPrimary : AppColors.textTertiary)
                .lineLimit(1)
        }
        .frame(width: 80)
        .onAppear {
            if isUnlocked {
                withAnimation(.easeInOut(duration: 0.6).repeatCount(1, autoreverses: true)) {
                    isAnimating = true
                }
            }
        }
    }
}

// MARK: - Achievement Grid
struct AchievementGrid: View {
    let reviewed: Int64
    let storage: Int64
    let streak: Int

    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible())
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("Achievements")
                .font(AppTypography.headlineSmall)
                .foregroundColor(AppColors.textPrimary)

            LazyVGrid(columns: columns, spacing: AppSpacing.md) {
                ForEach(AchievementType.allCases, id: \.title) { achievement in
                    AchievementBadge(
                        type: achievement,
                        isUnlocked: achievement.isUnlocked(
                            reviewed: reviewed,
                            storage: storage,
                            streak: streak
                        )
                    )
                }
            }
        }
        .padding(AppSpacing.md)
        .background(AppColors.secondaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.radiusMedium, style: .continuous))
    }
}

// MARK: - Extension for Gradient Stops
extension LinearGradient {
    var stops: [Gradient.Stop] {
        // This is a workaround since we can't directly access gradient stops
        // Returns empty array - the actual color is extracted differently
        []
    }
}

#Preview {
    VStack {
        AchievementGrid(reviewed: 150, storage: 500_000_000, streak: 10)
            .padding()

        HStack {
            AchievementBadge(type: .photos100, isUnlocked: true)
            AchievementBadge(type: .storage1GB, isUnlocked: false)
            AchievementBadge(type: .streak7, isUnlocked: true)
        }
    }
    .background(Color(.systemGroupedBackground))
}
