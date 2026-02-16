//
//  DashboardView.swift
//  PhotoReviewApp
//
//  Created by Muhammad Abdul Fattah on 03/02/25.
//
import Photos
import CoreData
import SwiftUI
import OSLog

struct DashboardView: View {
    @EnvironmentObject var analytics: CoreDataAnalyticsService
    @State private var animateElements = false
    @State private var selectedTimeFrame: TimeFrame = .allTime

    enum TimeFrame: String, CaseIterable {
        case thisWeek = "This Week"
        case allTime = "All Time"
    }

    var body: some View {
        ScrollView {
            VStack(spacing: AppSpacing.sectionSpacing) {
                // Header
                headerSection

                // Main metrics
                mainMetricsSection

                // Weekly chart
                WeeklyChartView(data: DayActivity.sampleWeek())
                    .opacity(animateElements ? 1 : 0)
                    .offset(y: animateElements ? 0 : 20)
                    .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.2), value: animateElements)

                // Stats grid
                statsGridSection

                // Achievements
                AchievementGrid(
                    reviewed: analytics.totalReviewed,
                    storage: analytics.totalStorageSaved,
                    streak: analytics.currentStreak
                )
                .opacity(animateElements ? 1 : 0)
                .offset(y: animateElements ? 0 : 20)
                .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.4), value: animateElements)
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.vertical, AppSpacing.lg)
        }
        .background(AppColors.groupedBackground)
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                animateElements = true
            }
        }
    }

    // MARK: - Header Section
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text("Photo Insights")
                .font(AppTypography.displaySmall)
                .foregroundColor(AppColors.textPrimary)

            Text("Track your photo organization progress")
                .font(AppTypography.bodySmall)
                .foregroundColor(AppColors.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .opacity(animateElements ? 1 : 0)
    }

    // MARK: - Main Metrics Section
    private var mainMetricsSection: some View {
        HStack(spacing: AppSpacing.sm) {
            // Storage Card
            MetricCard(
                title: "Storage Saved",
                icon: "externaldrive.badge.plus",
                value: analytics.totalStorageSaved.formatted(.byteCount(style: .file)),
                gradient: AppColors.storageGradient
            )
            .scaleEffect(animateElements ? 1 : 0.9)
            .opacity(animateElements ? 1 : 0)
            .animation(.spring(response: 0.5, dampingFraction: 0.8), value: animateElements)

            // Streak Card
            MetricCard(
                title: "Current Streak",
                icon: "flame.fill",
                value: "\(analytics.currentStreak) days",
                gradient: AppColors.streakGradient
            )
            .scaleEffect(animateElements ? 1 : 0.9)
            .opacity(animateElements ? 1 : 0)
            .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.1), value: animateElements)
        }
    }

    // MARK: - Stats Grid Section
    private var statsGridSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("Statistics")
                .font(AppTypography.headlineSmall)
                .foregroundColor(AppColors.textPrimary)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: AppSpacing.sm) {
                StatBadge(
                    title: "Reviewed",
                    value: analytics.totalReviewed,
                    icon: "checkmark.circle.fill",
                    gradient: AppColors.reviewedGradient
                )

                StatBadge(
                    title: "Deleted",
                    value: analytics.totalDeleted,
                    icon: "trash.fill",
                    gradient: AppColors.deletedGradient
                )

                StatBadge(
                    title: "Bookmarked",
                    value: analytics.totalBookmarked,
                    icon: "bookmark.fill",
                    gradient: AppColors.bookmarkedGradient
                )
            }
        }
        .opacity(animateElements ? 1 : 0)
        .offset(y: animateElements ? 0 : 20)
        .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.3), value: animateElements)
    }
}

// MARK: - Stat Badge Component
struct StatBadge: View {
    let title: String
    let value: Int64
    let icon: String
    let gradient: LinearGradient

    @State private var displayValue: Int64 = 0

    var body: some View {
        VStack(spacing: AppSpacing.xs) {
            // Icon
            ZStack {
                Circle()
                    .fill(gradient)
                    .frame(width: 44, height: 44)

                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.white)
            }

            // Value
            Text("\(displayValue)")
                .font(AppTypography.numberSmall)
                .foregroundColor(AppColors.textPrimary)
                .contentTransition(.numericText())

            // Title
            Text(title)
                .font(AppTypography.caption)
                .foregroundColor(AppColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppSpacing.sm)
        .background(AppColors.secondaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.radiusMedium, style: .continuous))
        .onAppear {
            withAnimation(.easeOut(duration: 0.8)) {
                displayValue = value
            }
        }
        .onChange(of: value) { _, newValue in
            withAnimation(.easeOut(duration: 0.3)) {
                displayValue = newValue
            }
        }
    }
}
