//
//  AnalyticsStore.swift
//  SnapSort
//
//  Created by Muhammad Abdul Fattah on 03/02/25.
//
import Foundation
import CoreData
import WidgetKit
import OSLog

/// Review activity for a single calendar day
struct DayActivity: Identifiable, Equatable {
    let date: Date
    var bookmarked: Int = 0
    var deleted: Int = 0

    var id: Date { date }
    var reviewed: Int { bookmarked + deleted }
}

protocol AnalyticsServiceProtocol {
    /// Bytes of photos actually deleted from the library through SnapSort.
    /// Trashing in the app only marks a photo, so it doesn't count until deleted.
    var totalSpaceCleared: Int64 { get }
    var currentStreak: Int { get }
    var totalReviewed: Int64 { get }
    var totalDeleted: Int64 { get }
    var totalBookmarked: Int64 { get }

    /// Records a single review decision
    func record(_ action: ReviewAction, assetIdentifier: String)
    /// Reverses `record` (used by undo)
    func revert(_ action: ReviewAction, assetIdentifier: String)
    /// Photos were restored from the trash after being reviewed
    func revertDeletion(assetIdentifiers: [String])
    /// Many photos were trashed at once (e.g. all photos of a person)
    func recordBulkDeletion(count: Int)
    /// Trashed photos were deleted from the library
    func recordSpaceCleared(_ bytes: Int64)
}

final class CoreDataAnalyticsService: ObservableObject, AnalyticsServiceProtocol {
    private let context: NSManagedObjectContext
    /// App-private flags (earned milestones, migrations)
    private let defaults: UserDefaults
    /// Shared with the widget; nil turns syncing off (tests)
    private let sharedDefaults: UserDefaults?
    private var analyticsEntity: AnalyticsEntity?
    private let calendar = Calendar.current

    /// Last seven days including today, oldest first
    @Published private(set) var weeklyActivity: [DayActivity] = []
    /// Consecutive days with at least one review, ending today or yesterday
    @Published private(set) var currentStreak: Int = 0
    /// Set when a milestone is reached; cleared by `acknowledgeMilestone()`
    @Published private(set) var newlyEarnedMilestone: AchievementType?

    private let earnedMilestonesKey = "earnedMilestones"
    private let spaceClearedMigrationKey = "spaceClearedCountsDeletedOnly"
    private let spaceClearedPendingKey = "spaceClearedMigrationPendingTrash"

    init(
        context: NSManagedObjectContext,
        defaults: UserDefaults = .standard,
        sharedDefaults: UserDefaults? = UserDefaults(suiteName: Constants.AppGroup.identifier)
    ) {
        self.context = context
        self.defaults = defaults
        self.sharedDefaults = sharedDefaults
        loadAnalytics()
        refreshDerivedStats()
        seedEarnedMilestonesIfNeeded()
        // The widget only hears about changes on save; catch it up at launch
        // (e.g. after the App Group changed or the streak lapsed overnight)
        syncToSharedDefaults()
    }

    private func loadAnalytics() {
        let request: NSFetchRequest<AnalyticsEntity> = AnalyticsEntity.fetchRequest()
        do {
            analyticsEntity = try context.fetch(request).first ?? AnalyticsEntity(context: context)
            try context.save()
        } catch {
            AppLogger.coreData.error("Error loading analytics: \(error.localizedDescription, privacy: .public)")
        }
    }

    // Stored as `totalStorageSaved` for compatibility with existing stores
    var totalSpaceCleared: Int64 { analyticsEntity?.totalStorageSaved ?? 0 }
    var totalReviewed: Int64 { analyticsEntity?.totalReviewed ?? 0 }
    var totalDeleted: Int64 { analyticsEntity?.totalDeleted ?? 0 }
    var totalBookmarked: Int64 { analyticsEntity?.totalBookmarked ?? 0 }

    // MARK: - Tracking

    func record(_ action: ReviewAction, assetIdentifier: String) {
        guard let entity = analyticsEntity else { return }
        objectWillChange.send()

        let record = ReviewRecord(context: context)
        record.id = UUID().uuidString
        record.assetIdentifier = assetIdentifier
        record.reviewDate = Date()
        record.userAction = action.rawValue

        entity.totalReviewed += 1
        switch action {
        case .bookmark:
            entity.totalBookmarked += 1
        case .delete:
            entity.totalDeleted += 1
        }

        let wasActiveToday = (todayActivity?.reviewed ?? 0) > 0
        adjustToday(action, by: 1)
        save()
        // The streak query only sees saved records, so recompute after saving
        if !wasActiveToday {
            recomputeStreak()
            save()
        }
        checkMilestones()
    }

    func revert(_ action: ReviewAction, assetIdentifier: String) {
        guard let entity = analyticsEntity else { return }
        objectWillChange.send()

        let request: NSFetchRequest<ReviewRecord> = ReviewRecord.fetchRequest()
        request.predicate = NSPredicate(format: "assetIdentifier == %@", assetIdentifier)
        request.sortDescriptors = [NSSortDescriptor(key: "reviewDate", ascending: false)]
        request.fetchLimit = 1
        if let record = try? context.fetch(request).first {
            if let date = record.reviewDate, calendar.isDateInToday(date) {
                adjustToday(action, by: -1)
            }
            context.delete(record)
        }

        entity.totalReviewed = max(0, entity.totalReviewed - 1)
        switch action {
        case .bookmark:
            entity.totalBookmarked = max(0, entity.totalBookmarked - 1)
        case .delete:
            entity.totalDeleted = max(0, entity.totalDeleted - 1)
        }

        save()
        // The streak query only sees saved records, so recompute after saving
        if (todayActivity?.reviewed ?? 0) == 0 {
            recomputeStreak()
            save()
        }
    }

    func revertDeletion(assetIdentifiers: [String]) {
        guard let entity = analyticsEntity, !assetIdentifiers.isEmpty else { return }
        objectWillChange.send()

        // A restored photo goes back into the review deck, so its trash
        // decision no longer counts as a review. Bulk deletions have no
        // per-photo record and only adjust the totals.
        let request: NSFetchRequest<ReviewRecord> = ReviewRecord.fetchRequest()
        request.predicate = NSPredicate(
            format: "assetIdentifier IN %@ AND userAction == %@",
            assetIdentifiers, ReviewAction.delete.rawValue
        )
        request.sortDescriptors = [NSSortDescriptor(key: "reviewDate", ascending: false)]
        var reverted = Set<String>()
        for record in (try? context.fetch(request)) ?? [] {
            guard let identifier = record.assetIdentifier, reverted.insert(identifier).inserted else { continue }
            if let date = record.reviewDate, calendar.isDateInToday(date) {
                adjustToday(.delete, by: -1)
            }
            context.delete(record)
        }

        entity.totalReviewed = max(0, entity.totalReviewed - Int64(reverted.count))
        entity.totalDeleted = max(0, entity.totalDeleted - Int64(assetIdentifiers.count))
        save()
        if !reverted.isEmpty {
            // The streak query only sees saved records, so recompute after saving
            recomputeStreak()
            save()
        }
    }

    func recordBulkDeletion(count: Int) {
        guard let entity = analyticsEntity, count > 0 else { return }
        objectWillChange.send()
        entity.totalDeleted += Int64(count)
        save()
    }

    func recordSpaceCleared(_ bytes: Int64) {
        guard let entity = analyticsEntity, bytes > 0 else { return }
        objectWillChange.send()
        entity.totalStorageSaved += bytes
        save()
        checkMilestones()
    }

    // MARK: - Migration

    /// Older builds counted a photo's size as soon as it was trashed. Notes
    /// which photos were already in the trash then, so their share can be
    /// taken off once sizes can be read. Call at launch, before anything new
    /// can be trashed. Runs once.
    func prepareSpaceClearedMigration(trashedIdentifiers: [String]) {
        guard !defaults.bool(forKey: spaceClearedMigrationKey) else { return }
        defaults.set(true, forKey: spaceClearedMigrationKey)
        // Fresh installs and stores that never counted anything need nothing
        guard totalSpaceCleared > 0, !trashedIdentifiers.isEmpty else { return }
        defaults.set(trashedIdentifiers, forKey: spaceClearedPendingKey)
    }

    /// Completes `prepareSpaceClearedMigration` once photo sizes are readable.
    @MainActor
    func finishSpaceClearedMigration(sizeOf: ([String]) async -> Int64) async {
        guard let identifiers = defaults.stringArray(forKey: spaceClearedPendingKey) else { return }
        // Cleared first so an overlapping call can't subtract twice
        defaults.removeObject(forKey: spaceClearedPendingKey)
        let bytes = await sizeOf(identifiers)
        guard let entity = analyticsEntity, bytes > 0 else { return }
        objectWillChange.send()
        entity.totalStorageSaved = max(0, entity.totalStorageSaved - bytes)
        save()
    }

    // MARK: - Milestones

    func acknowledgeMilestone() {
        newlyEarnedMilestone = nil
    }

    private func isEarned(_ achievement: AchievementType) -> Bool {
        switch achievement {
        case .photos100, .photos500, .photos1000: return totalReviewed >= achievement.threshold
        case .storage100MB, .storage1GB, .storage5GB: return totalSpaceCleared >= achievement.threshold
        case .streak7, .streak30, .streak100: return Int64(currentStreak) >= achievement.threshold
        }
    }

    private var earnedMilestoneKeys: Set<String> {
        get { Set(defaults.stringArray(forKey: earnedMilestonesKey) ?? []) }
        set { defaults.set(Array(newValue), forKey: earnedMilestonesKey) }
    }

    /// Existing users shouldn't get a burst of celebrations for old progress
    private func seedEarnedMilestonesIfNeeded() {
        guard defaults.object(forKey: earnedMilestonesKey) == nil else { return }
        earnedMilestoneKeys = Set(AchievementType.allCases.filter(isEarned).map(\.key))
    }

    private func checkMilestones() {
        let known = earnedMilestoneKeys
        let fresh = AchievementType.allCases.filter { isEarned($0) && !known.contains($0.key) }
        guard let latest = fresh.last else { return }
        earnedMilestoneKeys = known.union(fresh.map(\.key))
        newlyEarnedMilestone = latest
    }

    // MARK: - Derived Stats

    /// Rebuilds the weekly chart and streak from review records.
    /// Call when stats become visible — the day may have rolled over.
    func refreshDerivedStats() {
        weeklyActivity = fetchWeeklyActivity()
        recomputeStreak()
    }

    private var todayActivity: DayActivity? {
        weeklyActivity.last.flatMap { calendar.isDateInToday($0.date) ? $0 : nil }
    }

    private func adjustToday(_ action: ReviewAction, by delta: Int) {
        guard let last = weeklyActivity.indices.last,
              calendar.isDateInToday(weeklyActivity[last].date) else {
            // Day rolled over since the last refresh
            weeklyActivity = fetchWeeklyActivity()
            return
        }
        switch action {
        case .bookmark: weeklyActivity[last].bookmarked = max(0, weeklyActivity[last].bookmarked + delta)
        case .delete: weeklyActivity[last].deleted = max(0, weeklyActivity[last].deleted + delta)
        }
    }

    private func fetchWeeklyActivity() -> [DayActivity] {
        let today = calendar.startOfDay(for: Date())
        guard let start = calendar.date(byAdding: .day, value: -6, to: today) else { return [] }

        var days = (0..<7).compactMap { offset in
            calendar.date(byAdding: .day, value: offset, to: start).map { DayActivity(date: $0) }
        }

        let request: NSFetchRequest<ReviewRecord> = ReviewRecord.fetchRequest()
        request.predicate = NSPredicate(format: "reviewDate >= %@", start as NSDate)
        let records = (try? context.fetch(request)) ?? []

        for record in records {
            guard let date = record.reviewDate,
                  let index = calendar.dateComponents([.day], from: start, to: calendar.startOfDay(for: date)).day,
                  days.indices.contains(index) else { continue }
            switch ReviewAction(rawValue: record.userAction ?? "") {
            case .bookmark: days[index].bookmarked += 1
            case .delete: days[index].deleted += 1
            case nil: break
            }
        }
        return days
    }

    private func recomputeStreak() {
        let today = calendar.startOfDay(for: Date())
        guard let windowStart = calendar.date(byAdding: .day, value: -400, to: today),
              let yesterday = calendar.date(byAdding: .day, value: -1, to: today) else { return }

        let request = NSFetchRequest<NSDictionary>(entityName: "ReviewRecord")
        request.resultType = .dictionaryResultType
        request.propertiesToFetch = ["reviewDate"]
        request.predicate = NSPredicate(format: "reviewDate >= %@", windowStart as NSDate)

        let rows = (try? context.fetch(request)) ?? []
        let activeDays = Set(rows.compactMap { ($0["reviewDate"] as? Date).map(calendar.startOfDay) })

        // A streak survives until the end of the day after the last review
        var cursor = activeDays.contains(today) ? today : yesterday
        var streak = 0
        while activeDays.contains(cursor) {
            streak += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }

        currentStreak = streak
        analyticsEntity?.currentStreak = Int64(streak)
    }

    // MARK: - Persistence

    private func save() {
        do {
            try context.save()
            syncToSharedDefaults()
        } catch {
            AppLogger.coreData.error("Error saving analytics: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func syncToSharedDefaults() {
        guard let defaults = sharedDefaults else { return }
        defaults.set(currentStreak, forKey: Constants.SharedDefaults.streak)
        defaults.set(Int(totalSpaceCleared), forKey: Constants.SharedDefaults.spaceCleared)
        defaults.set(Int(totalReviewed), forKey: Constants.SharedDefaults.totalReviewed)
        defaults.set(Int(totalDeleted), forKey: Constants.SharedDefaults.totalDeleted)
        defaults.set(Int(totalBookmarked), forKey: Constants.SharedDefaults.totalBookmarked)
        WidgetCenter.shared.reloadTimelines(ofKind: Constants.Widget.kind)
    }
}
