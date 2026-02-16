//
//  WeeklyChartView.swift
//  PhotoReviewApp
//
//  Weekly activity bar chart
//

import SwiftUI

struct WeeklyChartView: View {
    let data: [DayActivity]
    @State private var animateChart = false

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            // Header
            HStack {
                Text("This Week")
                    .font(AppTypography.headlineSmall)
                    .foregroundColor(AppColors.textPrimary)

                Spacer()

                // Legend
                HStack(spacing: AppSpacing.md) {
                    LegendItem(color: AppColors.primary, label: "Reviewed")
                    LegendItem(color: AppColors.danger, label: "Deleted")
                }
            }

            // Chart
            HStack(alignment: .bottom, spacing: AppSpacing.xs) {
                ForEach(data) { day in
                    DayBar(
                        day: day,
                        maxValue: maxValue,
                        animate: animateChart
                    )
                }
            }
            .frame(height: 120)
            .padding(.top, AppSpacing.xs)
        }
        .padding(AppSpacing.md)
        .background(AppColors.secondaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.radiusMedium, style: .continuous))
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.2)) {
                animateChart = true
            }
        }
    }

    private var maxValue: Int {
        let maxReviewed = data.map { $0.reviewed }.max() ?? 1
        let maxDeleted = data.map { $0.deleted }.max() ?? 1
        return max(maxReviewed, maxDeleted, 1)
    }
}

// MARK: - Day Activity Model
struct DayActivity: Identifiable {
    let id = UUID()
    let dayName: String
    let reviewed: Int
    let deleted: Int
    let isToday: Bool

    static func sampleWeek() -> [DayActivity] {
        let calendar = Calendar.current
        let today = Date()
        let weekdaySymbols = calendar.shortWeekdaySymbols

        return (0..<7).map { offset in
            let date = calendar.date(byAdding: .day, value: -6 + offset, to: today)!
            let weekday = calendar.component(.weekday, from: date) - 1
            let isToday = calendar.isDateInToday(date)

            return DayActivity(
                dayName: String(weekdaySymbols[weekday].prefix(1)),
                reviewed: Int.random(in: 0...20),
                deleted: Int.random(in: 0...10),
                isToday: isToday
            )
        }
    }
}

// MARK: - Day Bar
struct DayBar: View {
    let day: DayActivity
    let maxValue: Int
    let animate: Bool

    private var reviewedHeight: CGFloat {
        guard maxValue > 0 else { return 0 }
        return CGFloat(day.reviewed) / CGFloat(maxValue) * 80
    }

    private var deletedHeight: CGFloat {
        guard maxValue > 0 else { return 0 }
        return CGFloat(day.deleted) / CGFloat(maxValue) * 80
    }

    var body: some View {
        VStack(spacing: AppSpacing.xxs) {
            // Bars
            HStack(alignment: .bottom, spacing: 2) {
                // Reviewed bar
                RoundedRectangle(cornerRadius: 3)
                    .fill(AppColors.primaryGradient)
                    .frame(width: 14, height: animate ? max(reviewedHeight, 4) : 4)

                // Deleted bar
                RoundedRectangle(cornerRadius: 3)
                    .fill(AppColors.deleteGradient)
                    .frame(width: 14, height: animate ? max(deletedHeight, 4) : 4)
            }
            .frame(height: 80, alignment: .bottom)

            // Day label
            Text(day.dayName)
                .font(AppTypography.labelSmall)
                .foregroundColor(day.isToday ? AppColors.primary : AppColors.textTertiary)
                .fontWeight(day.isToday ? .bold : .regular)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Legend Item
struct LegendItem: View {
    let color: Color
    let label: String

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)

            Text(label)
                .font(AppTypography.caption)
                .foregroundColor(AppColors.textSecondary)
        }
    }
}

#Preview {
    WeeklyChartView(data: DayActivity.sampleWeek())
        .padding()
        .background(Color(.systemGroupedBackground))
}
