//
//  ReviewStatsWidget.swift
//  PhotoReviewApp
//
//  Created by Muhammad Abdul Fattah on 04/02/25.
//
import WidgetKit
import SwiftUI

struct ReviewStatsWidget: Widget {
    let kind: String = Constants.Widget.kind

    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: kind,
            provider: StatsTimelineProvider()
        ) { (entry: StatsEntry) in
            StatsWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Review Stats")
        .description("Track your photo review progress")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Entry

struct StatsEntry: TimelineEntry {
    let date: Date
    let streak: Int
    let saved: Int64
    let totalReviewed: Int64
    let totalDeleted: Int64
    let totalBookmarked: Int64
}

// MARK: - Timeline Provider

struct StatsTimelineProvider: TimelineProvider {
    typealias Entry = StatsEntry

    func placeholder(in context: Context) -> StatsEntry {
        StatsEntry(date: Date(), streak: 0, saved: 0, totalReviewed: 0, totalDeleted: 0, totalBookmarked: 0)
    }

    func getSnapshot(in context: Context, completion: @escaping (StatsEntry) -> Void) {
        completion(readEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<StatsEntry>) -> Void) {
        let entry = readEntry()
        let nextUpdate = Calendar.current.date(byAdding: .hour, value: 1, to: Date())!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }

    private func readEntry() -> StatsEntry {
        let defaults = UserDefaults(suiteName: Constants.AppGroup.identifier)
        return StatsEntry(
            date: Date(),
            streak: defaults?.integer(forKey: Constants.SharedDefaults.streak) ?? 0,
            saved: Int64(defaults?.integer(forKey: Constants.SharedDefaults.storageSaved) ?? 0),
            totalReviewed: Int64(defaults?.integer(forKey: Constants.SharedDefaults.totalReviewed) ?? 0),
            totalDeleted: Int64(defaults?.integer(forKey: Constants.SharedDefaults.totalDeleted) ?? 0),
            totalBookmarked: Int64(defaults?.integer(forKey: Constants.SharedDefaults.totalBookmarked) ?? 0)
        )
    }
}

// MARK: - Widget View

struct StatsWidgetView: View {
    var entry: StatsEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .systemMedium:
            mediumView
        default:
            smallView
        }
    }

    // MARK: - Small Widget

    private var smallView: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: "photo.on.rectangle.angled")
                    .font(.system(size: 12))
                    .foregroundStyle(.indigo)
                Text("Photo Review")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            HStack(spacing: 4) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(.orange)
                Text("\(entry.streak)")
                    .font(.system(size: 28, weight: .bold, design: .rounded).monospacedDigit())
            }
            Text("day streak")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)

            Spacer()

            HStack(spacing: 4) {
                Image(systemName: "externaldrive.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(.teal)
                Text(entry.saved.formatted(.byteCount(style: .file)))
                    .font(.system(size: 14, weight: .semibold, design: .rounded).monospacedDigit())
                    .foregroundStyle(.teal)
            }
            Text("space saved")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
    }

    // MARK: - Medium Widget

    private var mediumView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 4) {
                Image(systemName: "photo.on.rectangle.angled")
                    .font(.system(size: 12))
                    .foregroundStyle(.indigo)
                Text("Photo Review")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                Spacer()
            }

            Spacer()

            HStack(spacing: 0) {
                statItem(
                    value: "\(entry.streak)",
                    label: "Streak",
                    icon: "flame.fill",
                    color: .orange
                )
                Spacer()
                statItem(
                    value: entry.saved.formatted(.byteCount(style: .file)),
                    label: "Saved",
                    icon: "externaldrive.fill",
                    color: .teal
                )
                Spacer()
                statItem(
                    value: "\(entry.totalReviewed)",
                    label: "Reviewed",
                    icon: "eye.fill",
                    color: .blue
                )
            }

            Spacer().frame(height: 4)

            HStack(spacing: 0) {
                statItem(
                    value: "\(entry.totalDeleted)",
                    label: "Deleted",
                    icon: "trash.fill",
                    color: .red
                )
                Spacer()
                statItem(
                    value: "\(entry.totalBookmarked)",
                    label: "Bookmarked",
                    icon: "bookmark.fill",
                    color: .purple
                )
                Spacer()
                Color.clear.frame(width: 80, height: 1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
    }

    private func statItem(value: String, label: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 10))
                    .foregroundStyle(color)
                Text(value)
                    .font(.system(size: 16, weight: .semibold, design: .rounded).monospacedDigit())
            }
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
        }
        .frame(width: 80, alignment: .leading)
    }
}

#Preview(as: .systemSmall) {
    ReviewStatsWidget()
} timeline: {
    StatsEntry(date: .now, streak: 7, saved: 150 * 1024 * 1024, totalReviewed: 42, totalDeleted: 12, totalBookmarked: 30)
}

#Preview(as: .systemMedium) {
    ReviewStatsWidget()
} timeline: {
    StatsEntry(date: .now, streak: 7, saved: 150 * 1024 * 1024, totalReviewed: 42, totalDeleted: 12, totalBookmarked: 30)
}
