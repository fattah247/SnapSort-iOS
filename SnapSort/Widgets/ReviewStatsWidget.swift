//
//  ReviewStatsWidget.swift
//  SnapSort
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
                // Looked up by name: this file is also compiled into the app,
                // whose catalog has no widget background
                .containerBackground(Color("WidgetBackground"), for: .widget)
        }
        .configurationDisplayName("Sorting Stats")
        .description("Your streak and how much space you've cleared.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Entry

struct StatsEntry: TimelineEntry {
    let date: Date
    let streak: Int
    /// Bytes of photos deleted through SnapSort
    let cleared: Int64
    let totalReviewed: Int64
    let totalDeleted: Int64
    let totalBookmarked: Int64
}

// MARK: - Timeline Provider

struct StatsTimelineProvider: TimelineProvider {
    typealias Entry = StatsEntry

    func placeholder(in context: Context) -> StatsEntry {
        StatsEntry(date: Date(), streak: 3, cleared: 120_000_000, totalReviewed: 48, totalDeleted: 15, totalBookmarked: 9)
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
            cleared: Int64(defaults?.integer(forKey: Constants.SharedDefaults.spaceCleared) ?? 0),
            totalReviewed: Int64(defaults?.integer(forKey: Constants.SharedDefaults.totalReviewed) ?? 0),
            totalDeleted: Int64(defaults?.integer(forKey: Constants.SharedDefaults.totalDeleted) ?? 0),
            totalBookmarked: Int64(defaults?.integer(forKey: Constants.SharedDefaults.totalBookmarked) ?? 0)
        )
    }
}

// MARK: - Widget View

struct StatsWidgetView: View {
    var entry: StatsEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        Group {
            switch family {
            case .systemMedium:
                HStack(alignment: .top, spacing: 16) {
                    streakColumn
                    statGrid
                }
            default:
                streakColumn
            }
        }
        .fontDesign(.rounded)
    }

    private var header: some View {
        Label {
            Text("SnapSort")
        } icon: {
            Image(systemName: "leaf.fill")
                .foregroundStyle(Color("AccentColor"))
                .widgetAccentable()
        }
        .font(.caption2.weight(.semibold))
        .foregroundStyle(.secondary)
        .labelStyle(.titleAndIcon)
    }

    private var streakColumn: some View {
        VStack(alignment: .leading, spacing: 2) {
            header
            Spacer(minLength: 4)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Image(systemName: "flame.fill")
                    .font(.title3)
                    .foregroundStyle(Color(.tangerine))
                    .widgetAccentable()
                Text(entry.streak.formatted())
                    .font(.system(size: 40, weight: .bold))
                    .monospacedDigit()
                    .contentTransition(.numericText())
            }
            Text(entry.streak == 0 ? "Sort a photo to start a streak" : "day streak")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
            Spacer(minLength: 4)
            if family == .systemSmall {
                Label {
                    Text("\(entry.cleared.formatted(.byteCount(style: .file))) cleared")
                        .monospacedDigit()
                } icon: {
                    Image(systemName: "internaldrive.fill")
                        .foregroundStyle(Color(.sky))
                        .widgetAccentable()
                }
                .font(.caption.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private var statGrid: some View {
        Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 12) {
            GridRow {
                stat(entry.cleared.formatted(.byteCount(style: .file)), "Cleared", "internaldrive.fill", Color(.sky))
                stat(entry.totalReviewed.formatted(), "Sorted", "checkmark.circle.fill", Color("AccentColor"))
            }
            GridRow {
                stat(entry.totalDeleted.formatted(), "Trashed", "trash.fill", Color(.tomato))
                stat(entry.totalBookmarked.formatted(), "Bookmarked", "bookmark.fill", Color(.honey))
            }
        }
        .frame(maxHeight: .infinity)
    }

    private func stat(_ value: String, _ label: String, _ icon: String, _ tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Image(systemName: icon)
                .font(.footnote)
                .foregroundStyle(tint)
                .widgetAccentable()
            Text(value)
                .font(.headline)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

#Preview(as: .systemSmall) {
    ReviewStatsWidget()
} timeline: {
    StatsEntry(date: .now, streak: 7, cleared: 150_000_000, totalReviewed: 42, totalDeleted: 12, totalBookmarked: 30)
    StatsEntry(date: .now, streak: 0, cleared: 0, totalReviewed: 0, totalDeleted: 0, totalBookmarked: 0)
}

#Preview(as: .systemMedium) {
    ReviewStatsWidget()
} timeline: {
    StatsEntry(date: .now, streak: 7, cleared: 150_000_000, totalReviewed: 42, totalDeleted: 12, totalBookmarked: 30)
}
