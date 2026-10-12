//
//  MilestonesView.swift
//  SnapSort
//
//  Milestones for reviewing, freeing space, and keeping a streak
//

import SwiftUI

// MARK: - Achievement Types
enum AchievementType: CaseIterable, Identifiable {
    case photos100, photos500, photos1000
    case storage100MB, storage1GB, storage5GB
    case streak7, streak30, streak100

    /// Stable identifier for persistence
    var key: String { String(describing: self) }
    var id: String { key }

    var systemImage: String {
        switch self {
        case .photos100, .photos500, .photos1000: return "photo.stack"
        case .storage100MB, .storage1GB, .storage5GB: return "internaldrive"
        case .streak7, .streak30, .streak100: return "flame.fill"
        }
    }

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
        case .photos1000: return "Review 1,000 photos"
        case .storage100MB: return "Clear 100 MB"
        case .storage1GB: return "Clear 1 GB"
        case .storage5GB: return "Clear 5 GB"
        case .streak7: return "Review 7 days in a row"
        case .streak30: return "Review 30 days in a row"
        case .streak100: return "Review 100 days in a row"
        }
    }

    var threshold: Int64 {
        switch self {
        case .photos100: return 100
        case .photos500: return 500
        case .photos1000: return 1000
        case .storage100MB: return 100_000_000
        case .storage1GB: return 1_000_000_000
        case .storage5GB: return 5_000_000_000
        case .streak7: return 7
        case .streak30: return 30
        case .streak100: return 100
        }
    }
}

// MARK: - Milestone Tracks

/// Each track is a ladder of achievements measured against one stat
enum MilestoneTrack: CaseIterable, Identifiable {
    case reviewing, storage, streak

    var id: Self { self }

    var systemImage: String {
        switch self {
        case .reviewing: return "photo.stack"
        case .storage: return "internaldrive"
        case .streak: return "flame.fill"
        }
    }

    var tint: Color {
        switch self {
        case .reviewing: return AppColors.brand
        case .storage: return AppColors.storage
        case .streak: return AppColors.streak
        }
    }

    var tiers: [AchievementType] {
        switch self {
        case .reviewing: return [.photos100, .photos500, .photos1000]
        case .storage: return [.storage100MB, .storage1GB, .storage5GB]
        case .streak: return [.streak7, .streak30, .streak100]
        }
    }

    var completedTitle: String {
        switch self {
        case .reviewing: return "Every review milestone reached"
        case .storage: return "Every storage milestone reached"
        case .streak: return "Every streak milestone reached"
        }
    }

    func format(_ value: Int64) -> String {
        switch self {
        case .reviewing: return value.formatted()
        case .storage: return value.storageText
        case .streak: return value.formatted()
        }
    }
}

// MARK: - Milestones View

struct MilestonesView: View {
    let reviewed: Int64
    let storage: Int64
    let streak: Int

    private func value(for track: MilestoneTrack) -> Int64 {
        switch track {
        case .reviewing: return reviewed
        case .storage: return storage
        case .streak: return Int64(streak)
        }
    }

    private var earnedCount: Int {
        MilestoneTrack.allCases.reduce(0) { count, track in
            count + track.tiers.filter { value(for: track) >= $0.threshold }.count
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack(alignment: .firstTextBaseline) {
                Text("Milestones")
                    .font(.headline)
                Spacer()
                Text("\(earnedCount) of \(AchievementType.allCases.count) earned")
                    .font(.subheadline)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }

            ForEach(MilestoneTrack.allCases) { track in
                if track != MilestoneTrack.allCases.first {
                    Divider()
                }
                MilestoneRow(track: track, value: value(for: track))
            }
        }
        .cardStyle()
    }
}

private struct MilestoneRow: View {
    let track: MilestoneTrack
    let value: Int64

    private var nextTier: AchievementType? {
        track.tiers.first { value < $0.threshold }
    }

    private var earnedTiers: [AchievementType] {
        track.tiers.filter { value >= $0.threshold }
    }

    private var fraction: Double {
        guard let nextTier else { return 1 }
        return min(Double(value) / Double(nextTier.threshold), 1)
    }

    var body: some View {
        HStack(alignment: .top, spacing: AppSpacing.sm) {
            Image(systemName: nextTier == nil ? "checkmark.seal.fill" : track.systemImage)
                .iconTile(track.tint, size: 32)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                HStack(alignment: .firstTextBaseline) {
                    Text(nextTier?.description ?? track.completedTitle)
                        .font(.subheadline.weight(.semibold))
                    Spacer(minLength: AppSpacing.xs)
                    if let nextTier {
                        Text("\(track.format(value)) / \(track.format(nextTier.threshold))")
                            .font(.footnote)
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                }

                ProgressView(value: fraction)
                    .progressViewStyle(ChunkyProgressStyle(tint: track.tint, height: 8))

                if !earnedTiers.isEmpty {
                    Text("Earned: \(earnedTiers.map(\.title).joined(separator: ", "))")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    MilestonesView(reviewed: 150, storage: 500_000_000, streak: 10)
        .padding()
        .background(AppColors.groupedBackground)
}
