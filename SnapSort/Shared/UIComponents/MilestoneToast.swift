//
//  MilestoneToast.swift
//  SnapSort
//
//  Celebrates a newly reached milestone, then gets out of the way.
//

import SwiftUI

struct MilestoneToast: View {
    let milestone: AchievementType
    let onDismiss: () -> Void

    var body: some View {
        ZStack(alignment: .top) {
            ConfettiView(pieceCount: 50, duration: 2.4)

            HStack(spacing: AppSpacing.sm) {
                Snappy(mood: .cheer, size: 54, animated: false)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Milestone reached!")
                        .font(.caption.weight(.heavy))
                        .foregroundStyle(.tint)
                        .textCase(.uppercase)
                    Text(milestone.title)
                        .font(.headline)
                    Text(milestone.description)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
            .padding(AppSpacing.sm)
            .background(
                AppColors.cardBackground,
                in: RoundedRectangle(cornerRadius: AppSpacing.radiusLarge, style: .continuous)
            )
            .shadow(color: .black.opacity(0.12), radius: 16, y: 6)
            .padding(.horizontal, AppSpacing.md)
            .padding(.top, AppSpacing.xs)
            .onTapGesture(perform: onDismiss)
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isButton)
            .accessibilityHint("Dismisses")
        }
        .sensoryFeedback(.success, trigger: milestone)
        .task {
            AccessibilityNotification.Announcement("Milestone reached: \(milestone.title). \(milestone.description)").post()
            try? await Task.sleep(for: .seconds(4))
            onDismiss()
        }
    }
}
