//
//  WeeklyChartView.swift
//  SnapSort
//
//  Photos reviewed per day over the last week
//

import SwiftUI
import Charts

struct WeeklyChartView: View {
    let data: [DayActivity]

    @State private var selectedDate: Date?

    private var totalReviewed: Int { data.reduce(0) { $0 + $1.reviewed } }
    private var totalDeleted: Int { data.reduce(0) { $0 + $1.deleted } }
    private var totalBookmarked: Int { data.reduce(0) { $0 + $1.bookmarked } }

    private var selectedDay: DayActivity? {
        guard let selectedDate else { return nil }
        return data.first { Calendar.current.isDate($0.date, inSameDayAs: selectedDate) }
    }

    private var yUpperBound: Int {
        // Keep a sensible scale when the week is empty or nearly so
        max(data.map(\.reviewed).max() ?? 0, 4)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            header

            Chart(data) { day in
                BarMark(
                    x: .value("Day", day.date, unit: .day),
                    y: .value("Reviewed", day.reviewed),
                    width: .ratio(0.5)
                )
                .cornerRadius(4)
                .foregroundStyle(AppColors.brand.opacity(isEmphasized(day) ? 1 : 0.3))
                .accessibilityLabel(day.date.formatted(.dateTime.weekday(.wide)))
                .accessibilityValue("\(day.reviewed) reviewed, \(day.deleted) trashed, \(day.bookmarked) bookmarked")
            }
            .chartXSelection(value: $selectedDate)
            .chartYScale(domain: 0...yUpperBound)
            .chartXAxis {
                AxisMarks(values: .stride(by: .day)) { _ in
                    AxisValueLabel(format: .dateTime.weekday(.narrow), centered: true)
                }
            }
            .chartYAxis {
                AxisMarks(values: .automatic(desiredCount: 3)) { _ in
                    AxisGridLine()
                    AxisValueLabel()
                }
            }
            .frame(height: 160)
            .overlay {
                if totalReviewed == 0 {
                    Text("No reviews this week")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Divider()

            HStack {
                breakdownItem(title: "Trashed", value: selectedDay?.deleted ?? totalDeleted, tint: AppColors.delete)
                Spacer()
                breakdownItem(title: "Bookmarked", value: selectedDay?.bookmarked ?? totalBookmarked, tint: AppColors.keep)
            }
        }
        .cardStyle()
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Last 7 Days")
                .font(.headline)
            Group {
                if let selectedDay {
                    Text("^[\(selectedDay.reviewed) photo](inflect: true) reviewed on \(selectedDay.date.formatted(.dateTime.weekday(.wide)))")
                } else {
                    Text("^[\(totalReviewed) photo](inflect: true) reviewed")
                }
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .monospacedDigit()
        }
        .accessibilityElement(children: .combine)
    }

    private func isEmphasized(_ day: DayActivity) -> Bool {
        guard let selectedDay else { return true }
        return selectedDay.id == day.id
    }

    private func breakdownItem(title: String, value: Int, tint: Color) -> some View {
        HStack(spacing: AppSpacing.xs) {
            Circle()
                .fill(tint)
                .frame(width: 8, height: 8)
                .accessibilityHidden(true)
            Text(title)
                .foregroundStyle(.secondary)
            Text(value, format: .number)
                .monospacedDigit()
        }
        .font(.subheadline)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    let calendar = Calendar.current
    let today = calendar.startOfDay(for: Date())
    let sample = (0..<7).map { offset in
        DayActivity(
            date: calendar.date(byAdding: .day, value: offset - 6, to: today)!,
            bookmarked: [2, 0, 5, 3, 1, 8, 4][offset],
            deleted: [6, 0, 9, 4, 2, 12, 7][offset]
        )
    }
    return WeeklyChartView(data: sample)
        .padding()
        .background(AppColors.groupedBackground)
}
