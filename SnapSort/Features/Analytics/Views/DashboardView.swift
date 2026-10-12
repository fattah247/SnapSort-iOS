//
//  DashboardView.swift
//  SnapSort
//
//  Created by Muhammad Abdul Fattah on 03/02/25.
//
import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var analytics: CoreDataAnalyticsService

    private let columns = [
        GridItem(.flexible(), spacing: AppSpacing.sm),
        GridItem(.flexible(), spacing: AppSpacing.sm)
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppSpacing.md) {
                    greeting

                    LazyVGrid(columns: columns, spacing: AppSpacing.sm) {
                        MetricCard(
                            title: "Space Cleared",
                            systemImage: "internaldrive.fill",
                            tint: AppColors.storage,
                            value: analytics.totalSpaceCleared.storageText
                        )
                        MetricCard(
                            title: "Streak",
                            systemImage: "flame.fill",
                            tint: AppColors.streak,
                            value: Text("^[\(analytics.currentStreak) day](inflect: true)")
                        )
                        MetricCard(
                            title: "Trashed",
                            systemImage: "trash.fill",
                            tint: AppColors.delete,
                            value: analytics.totalDeleted.formatted()
                        )
                        MetricCard(
                            title: "Bookmarked",
                            systemImage: "bookmark.fill",
                            tint: AppColors.keep,
                            value: analytics.totalBookmarked.formatted()
                        )
                    }

                    Text("Space Cleared counts photos you've deleted from the Trash. iOS keeps them in Recently Deleted for up to 30 days before the space is free.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, AppSpacing.xs)

                    WeeklyChartView(data: analytics.weeklyActivity)

                    MilestonesView(
                        reviewed: analytics.totalReviewed,
                        storage: analytics.totalSpaceCleared,
                        streak: analytics.currentStreak
                    )
                }
                .padding(.horizontal, AppSpacing.md)
                .padding(.bottom, AppSpacing.lg)
                .frame(maxWidth: 720)
                .frame(maxWidth: .infinity)
            }
            .background(AppColors.groupedBackground)
            .navigationTitle("Stats")
            .onAppear {
                // The day may have rolled over since stats were last computed
                analytics.refreshDerivedStats()
            }
        }
    }

    private var greeting: some View {
        HStack(spacing: AppSpacing.sm) {
            Snappy(mood: analytics.currentStreak > 0 ? .cheer : .happy, size: 64)
            VStack(alignment: .leading, spacing: 2) {
                Text(greetingTitle)
                    .font(.headline)
                Text(greetingMessage)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .cardStyle()
        .accessibilityElement(children: .combine)
    }

    private var greetingTitle: String {
        switch analytics.currentStreak {
        case 0: return analytics.totalReviewed == 0 ? "Ready when you are!" : "Welcome back!"
        case 1: return "Day one — nice start!"
        default: return "\(analytics.currentStreak) days in a row!"
        }
    }

    private var greetingMessage: String {
        if analytics.totalReviewed == 0 {
            return "Sort a few photos and your progress will show up here."
        }
        return "You've sorted \(analytics.totalReviewed.formatted()) photos so far. Keep it up!"
    }
}
