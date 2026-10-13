//
//  SnapSortTests.swift
//  SnapSortTests
//
//  Created by Muhammad Abdul Fattah on 28/01/25.
//

import CoreData
import CoreImage
import Foundation
import Testing
import UserNotifications
@testable import SnapSort

// MARK: - Test Images

private enum TestImages {
    /// Deterministic high-frequency texture: a checkerboard with pseudo-random speckle
    static func texture(seed: UInt64 = 7, size: Int = 1024) -> CGImage {
        var state = seed
        func next() -> UInt64 {
            state = state &* 6364136223846793005 &+ 1442695040888963407
            return state >> 33
        }
        return render(size: size) { context in
            let cell = size / 32
            for y in 0..<32 {
                for x in 0..<32 {
                    let base: CGFloat = (x + y).isMultiple(of: 2) ? 0.85 : 0.15
                    let jitter = CGFloat(next() % 100) / 500
                    context.setFillColor(gray: min(1, base + jitter), alpha: 1)
                    context.fill(CGRect(x: x * cell, y: y * cell, width: cell, height: cell))
                }
            }
            for _ in 0..<1500 {
                let value = CGFloat(next() % 255) / 255
                context.setFillColor(gray: value, alpha: 1)
                context.fill(CGRect(x: Int(next() % UInt64(size)), y: Int(next() % UInt64(size)), width: 3, height: 3))
            }
        }
    }

    /// Smooth gradient with a few soft shapes — distinct from `texture`
    static func scene(size: Int = 1024) -> CGImage {
        render(size: size) { context in
            for row in 0..<size {
                context.setFillColor(gray: CGFloat(row) / CGFloat(size), alpha: 1)
                context.fill(CGRect(x: 0, y: row, width: size, height: 1))
            }
            context.setFillColor(gray: 0.05, alpha: 1)
            context.fillEllipse(in: CGRect(x: size / 5, y: size / 3, width: size / 3, height: size / 3))
            context.setFillColor(gray: 0.95, alpha: 1)
            context.fill(CGRect(x: size * 3 / 5, y: size / 8, width: size / 4, height: size / 2))
        }
    }

    static func solid(gray: CGFloat, size: Int = 256) -> CGImage {
        render(size: size) { context in
            context.setFillColor(gray: gray, alpha: 1)
            context.fill(CGRect(x: 0, y: 0, width: size, height: size))
        }
    }

    /// Mostly black with a sprinkle of bright lights, like a city at night
    static func nightLights(size: Int = 256) -> CGImage {
        render(size: size) { context in
            context.setFillColor(gray: 0.02, alpha: 1)
            context.fill(CGRect(x: 0, y: 0, width: size, height: size))
            context.setFillColor(gray: 1, alpha: 1)
            for index in 0..<60 {
                context.fill(CGRect(x: (index * 37) % size, y: (index * 53) % size, width: 10, height: 10))
            }
        }
    }

    static func blurred(_ image: CGImage, sigma: Double) -> CGImage {
        let input = CIImage(cgImage: image)
        let output = input.clampedToExtent().applyingGaussianBlur(sigma: sigma).cropped(to: input.extent)
        return CIContext().createCGImage(output, from: output.extent)!
    }

    static func adjusted(_ image: CGImage, crop: CGFloat, exposure: Double) -> CGImage {
        let input = CIImage(cgImage: image)
        let extent = input.extent.insetBy(dx: input.extent.width * crop, dy: input.extent.height * crop)
        let output = input.cropped(to: extent).applyingFilter("CIExposureAdjust", parameters: [kCIInputEVKey: exposure])
        return CIContext().createCGImage(output, from: output.extent)!
    }

    private static func render(size: Int, _ draw: (CGContext) -> Void) -> CGImage {
        let context = CGContext(
            data: nil,
            width: size,
            height: size,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        )!
        draw(context)
        return context.makeImage()!
    }
}

// MARK: - Image Metrics

@Suite("Image metrics")
struct ImageMetricsTests {
    @Test func sharpTextureIsNotBlurry() {
        #expect(ImageMetrics.blurriness(TestImages.texture()) < Constants.Analysis.blurThreshold)
    }

    @Test func blurredTextureIsBlurry() {
        let blurred = TestImages.blurred(TestImages.texture(), sigma: 4)
        #expect(ImageMetrics.blurriness(blurred) > Constants.Analysis.blurThreshold)
    }

    @Test func blurIncreasesBlurriness() {
        let sharp = ImageMetrics.blurriness(TestImages.texture())
        let soft = ImageMetrics.blurriness(TestImages.blurred(TestImages.texture(), sigma: 1.5))
        let mush = ImageMetrics.blurriness(TestImages.blurred(TestImages.texture(), sigma: 5))
        #expect(sharp < soft)
        #expect(soft < mush)
    }

    @Test func flatImageIsNotJudgedBlurry() {
        // Nothing to measure — a plain wall shouldn't be flagged
        #expect(ImageMetrics.blurriness(TestImages.solid(gray: 0.5)) < Constants.Analysis.blurThreshold)
    }

    @Test func pocketShotIsTooDark() throws {
        let exposure = try #require(ImageMetrics.exposure(TestImages.solid(gray: 0.03)))
        #expect(exposure.isTooDark)
        #expect(!exposure.isTooBright)
    }

    @Test func nightSceneWithLightsIsNotTooDark() throws {
        let exposure = try #require(ImageMetrics.exposure(TestImages.nightLights()))
        #expect(exposure.mean < Constants.Analysis.darkMeanThreshold)
        #expect(!exposure.isTooDark)
    }

    @Test func washedOutFrameIsTooBright() throws {
        let exposure = try #require(ImageMetrics.exposure(TestImages.solid(gray: 0.99)))
        #expect(exposure.isTooBright)
    }

    @Test func balancedSceneIsFine() throws {
        let exposure = try #require(ImageMetrics.exposure(TestImages.scene()))
        #expect(!exposure.isTooDark)
        #expect(!exposure.isTooBright)
    }

    @Test func differenceHashToleratesRetakes() throws {
        let original = try #require(ImageMetrics.differenceHash(TestImages.scene()))
        let retake = try #require(ImageMetrics.differenceHash(TestImages.adjusted(TestImages.scene(), crop: 0.03, exposure: 0.2)))
        let blurredRetake = try #require(ImageMetrics.differenceHash(TestImages.blurred(TestImages.scene(), sigma: 3)))
        #expect((original ^ retake).nonzeroBitCount <= Constants.Analysis.similarHashThreshold)
        #expect((original ^ blurredRetake).nonzeroBitCount <= Constants.Analysis.similarHashThreshold)
    }

    @Test func differenceHashSeparatesDifferentPhotos() throws {
        let scene = try #require(ImageMetrics.differenceHash(TestImages.scene()))
        let texture = try #require(ImageMetrics.differenceHash(TestImages.texture()))
        #expect((scene ^ texture).nonzeroBitCount > Constants.Analysis.similarHashThreshold)
    }
}

// MARK: - Similar Shots

@Suite("Similar shots")
struct SimilarShotsTests {
    private func signature(_ image: CGImage) -> SimilaritySignature {
        SimilaritySignature(pixelHash: ImageMetrics.differenceHash(image), featurePrint: nil)
    }

    @Test func signatureRoundTripsThroughStorage() throws {
        let original = signature(TestImages.scene())
        let data = try #require(original.data)
        let decoded = try #require(SimilaritySignature(data: data))
        #expect(decoded.pixelHash == original.pixelHash)
        #expect(decoded.featurePrint == nil)
    }

    @Test func garbageDataIsRejected() {
        #expect(SimilaritySignature(data: Data([1, 2, 3])) == nil)
    }

    @Test func retakesTakenTogetherFormOneSet() {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let photos = [
            (identifier: "a", date: start),
            (identifier: "b", date: start.addingTimeInterval(2)),
            (identifier: "c", date: start.addingTimeInterval(4)),
            (identifier: "other", date: start.addingTimeInterval(6))
        ]
        let prints: [String: Data] = [
            "a": signature(TestImages.scene()).data!,
            "b": signature(TestImages.adjusted(TestImages.scene(), crop: 0.03, exposure: 0.15)).data!,
            "c": signature(TestImages.blurred(TestImages.scene(), sigma: 2.5)).data!,
            "other": signature(TestImages.texture()).data!
        ]

        let groups = SimilarShotsStore.group(photos, archivedPrints: prints)
        #expect(groups.count == 1)
        #expect(groups.first?.assetIdentifiers == ["a", "b", "c"])
    }

    @Test func lookalikesHoursApartAreNotGrouped() {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let photos = [
            (identifier: "morning", date: start),
            (identifier: "evening", date: start.addingTimeInterval(8 * 3600))
        ]
        let data = signature(TestImages.scene()).data!
        let groups = SimilarShotsStore.group(photos, archivedPrints: ["morning": data, "evening": data])
        #expect(groups.isEmpty)
    }

    @Test func groupIDChangesWhenMembershipChanges() {
        let pair = SimilarShotGroup(assetIdentifiers: ["a", "b"])
        let trio = SimilarShotGroup(assetIdentifiers: ["a", "b", "c"])
        #expect(pair.id != trio.id)
    }
}

// MARK: - Reminders

@Suite("Reminder scheduling")
struct ReminderTests {
    private let base = DateComponents(hour: 19, minute: 30)
    private let service = NotificationService()

    @Test func dailyFiresOncePerDay() {
        let triggers = service.triggerComponents(base: base, repeatInterval: .daily, weekdays: [], monthDay: 1)
        #expect(triggers == [base])
    }

    @Test func weeklyFiresOnEachChosenDay() {
        let triggers = service.triggerComponents(base: base, repeatInterval: .weekly, weekdays: [.mon, .wed], monthDay: 1)
        #expect(triggers.map(\.weekday) == [2, 4])
        #expect(triggers.allSatisfy { $0.hour == 19 && $0.minute == 30 })
    }

    @Test func weeklyWithNoDaysFallsBackToToday() {
        let triggers = service.triggerComponents(base: base, repeatInterval: .weekly, weekdays: [], monthDay: 1)
        #expect(triggers.count == 1)
        #expect(triggers.first?.weekday == Calendar.current.component(.weekday, from: Date()))
    }

    @Test func monthlyFiresOnChosenDay() {
        let triggers = service.triggerComponents(base: base, repeatInterval: .monthly, weekdays: [], monthDay: 15)
        #expect(triggers.first?.day == 15)
    }
}

// MARK: - Settings

@Suite("Settings")
struct SettingsTests {
    @Test func legacyBinaryMegabytesSnapToStepperGrid() {
        // Older builds stored 100 MiB
        #expect(SettingsViewModel.snappedStorageTarget(104_857_600) == 100_000_000)
    }

    @Test func storageTargetIsClampedToRange() {
        #expect(SettingsViewModel.snappedStorageTarget(5_000_000) == SettingsViewModel.storageTargetRange.lowerBound)
        #expect(SettingsViewModel.snappedStorageTarget(9_000_000_000) == SettingsViewModel.storageTargetRange.upperBound)
    }

    @Test func weekdaysFollowLocaleOrder() {
        let ordered = Weekday.localeOrdered
        #expect(ordered.count == 7)
        #expect(ordered.first?.rawValue == Calendar.current.firstWeekday)
    }

    @Test func yearRangeCoversTheWholeYear() throws {
        let range = try #require(2021.yearRange)
        let calendar = Calendar.current
        #expect(calendar.component(.year, from: range.lowerBound) == 2021)
        #expect(range.contains(calendar.date(from: DateComponents(year: 2021, month: 12, day: 31, hour: 23))!))
        #expect(!range.contains(calendar.date(from: DateComponents(year: 2022, month: 1, day: 1))!))
    }
}

// MARK: - Core Data Helpers

private enum TestStore {
    /// In-memory store using the app's own model instance. Reusing the loaded
    /// model avoids "multiple entity descriptions" ambiguity in the test host.
    static func makeContext() throws -> NSManagedObjectContext {
        let model = try #require(CoreDataManager.shared.viewContext.persistentStoreCoordinator?.managedObjectModel)
        let coordinator = NSPersistentStoreCoordinator(managedObjectModel: model)
        try coordinator.addPersistentStore(ofType: NSInMemoryStoreType, configurationName: nil, at: nil)
        let context = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
        context.persistentStoreCoordinator = coordinator
        return context
    }

    /// Empty defaults of their own, so tests never touch the host app's
    /// settings, milestones or the widget's shared stats
    static func makeDefaults() -> UserDefaults {
        let name = "SnapSortTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    static func makeAnalytics(
        context: NSManagedObjectContext? = nil,
        defaults: UserDefaults = makeDefaults()
    ) throws -> CoreDataAnalyticsService {
        CoreDataAnalyticsService(context: try context ?? makeContext(), defaults: defaults, sharedDefaults: nil)
    }
}

// MARK: - Analytics

@Suite("Analytics", .serialized)
@MainActor
struct AnalyticsTests {

    @Test func recordingUpdatesTotalsAndToday() throws {
        let analytics = try TestStore.makeAnalytics()
        analytics.record(.delete, assetIdentifier: "p1")
        analytics.record(.bookmark, assetIdentifier: "p2")

        #expect(analytics.totalReviewed == 2)
        #expect(analytics.totalDeleted == 1)
        #expect(analytics.totalBookmarked == 1)
        // Trashing only marks a photo — nothing is cleared until it's deleted
        #expect(analytics.totalSpaceCleared == 0)
        #expect(analytics.weeklyActivity.count == 7)
        #expect(analytics.weeklyActivity.last?.deleted == 1)
        #expect(analytics.weeklyActivity.last?.bookmarked == 1)
        #expect(analytics.currentStreak == 1)
    }

    @Test func undoRevertsEverything() throws {
        let analytics = try TestStore.makeAnalytics()
        analytics.record(.delete, assetIdentifier: "p1")
        analytics.revert(.delete, assetIdentifier: "p1")

        #expect(analytics.totalReviewed == 0)
        #expect(analytics.totalDeleted == 0)
        #expect(analytics.weeklyActivity.last?.reviewed == 0)
        #expect(analytics.currentStreak == 0)
    }

    @Test func restoringFromTrashNeverGoesNegative() throws {
        let analytics = try TestStore.makeAnalytics()
        analytics.record(.delete, assetIdentifier: "p1")
        analytics.revertDeletion(assetIdentifiers: ["p1", "p2", "p3", "p4", "p5"])
        #expect(analytics.totalDeleted == 0)
        #expect(analytics.totalReviewed == 0)
    }

    @Test func restoringFromTrashKeepsChartAndTotalsInStep() throws {
        let analytics = try TestStore.makeAnalytics()
        analytics.record(.delete, assetIdentifier: "p1")
        analytics.record(.delete, assetIdentifier: "p2")
        analytics.record(.bookmark, assetIdentifier: "p3")

        analytics.revertDeletion(assetIdentifiers: ["p1"])

        #expect(analytics.totalDeleted == 1)
        #expect(analytics.totalReviewed == 2)
        #expect(analytics.weeklyActivity.last?.deleted == 1)
        #expect(analytics.weeklyActivity.last?.bookmarked == 1)
        #expect(analytics.currentStreak == 1)

        // Fresh read from the store agrees with the in-memory counts
        analytics.refreshDerivedStats()
        #expect(analytics.weeklyActivity.last?.deleted == 1)
    }

    @Test func restoringEverythingFromTodayEndsTheStreak() throws {
        let analytics = try TestStore.makeAnalytics()
        analytics.record(.delete, assetIdentifier: "p1")
        #expect(analytics.currentStreak == 1)
        analytics.revertDeletion(assetIdentifiers: ["p1"])
        #expect(analytics.currentStreak == 0)
        #expect(analytics.weeklyActivity.last?.reviewed == 0)
    }

    @Test func onlyDeletedPhotosCountAsSpaceCleared() throws {
        let analytics = try TestStore.makeAnalytics()
        analytics.record(.delete, assetIdentifier: "p1")
        analytics.recordBulkDeletion(count: 20)
        #expect(analytics.totalSpaceCleared == 0)

        analytics.recordSpaceCleared(4_000_000)
        analytics.recordSpaceCleared(0)
        #expect(analytics.totalSpaceCleared == 4_000_000)

        // Restoring something still in the trash doesn't touch deleted space
        analytics.revertDeletion(assetIdentifiers: ["p1"])
        #expect(analytics.totalSpaceCleared == 4_000_000)
    }

    @Test func legacyTrashedSpaceIsRemovedOnce() async throws {
        // An older build counted 5 MB: 2 MB already deleted, 3 MB still in the trash
        let context = try TestStore.makeContext()
        let legacy = AnalyticsEntity(context: context)
        legacy.totalStorageSaved = 5_000_000
        try context.save()
        let analytics = try TestStore.makeAnalytics(context: context)

        analytics.prepareSpaceClearedMigration(trashedIdentifiers: ["a", "b"])
        // Photos trashed after launch must not be part of the adjustment
        analytics.prepareSpaceClearedMigration(trashedIdentifiers: ["a", "b", "new"])

        var asked: [String] = []
        await analytics.finishSpaceClearedMigration { identifiers in
            asked = identifiers
            return 3_000_000
        }
        await analytics.finishSpaceClearedMigration { _ in 3_000_000 }

        #expect(asked == ["a", "b"])
        #expect(analytics.totalSpaceCleared == 2_000_000)
    }

    @Test func freshInstallsSkipTheLegacyAdjustment() async throws {
        let analytics = try TestStore.makeAnalytics()
        analytics.prepareSpaceClearedMigration(trashedIdentifiers: ["a"])
        var wasAsked = false
        await analytics.finishSpaceClearedMigration { _ in
            wasAsked = true
            return 1_000
        }
        #expect(!wasAsked)
        #expect(analytics.totalSpaceCleared == 0)
    }

    @Test func streakCountsConsecutiveDays() throws {
        let context = try TestStore.makeContext()
        let calendar = Calendar.current
        // Today, yesterday and the day before — then a gap
        for daysAgo in [0, 1, 2, 4] {
            let record = ReviewRecord(context: context)
            record.id = UUID().uuidString
            record.assetIdentifier = "p\(daysAgo)"
            record.userAction = ReviewAction.delete.rawValue
            record.reviewDate = calendar.date(byAdding: .day, value: -daysAgo, to: Date())
        }
        try context.save()

        let analytics = try TestStore.makeAnalytics(context: context)
        #expect(analytics.currentStreak == 3)
        #expect(analytics.weeklyActivity.filter { $0.reviewed > 0 }.count == 4)
    }

    @Test func streakSurvivesUntilTheEndOfTheNextDay() throws {
        let context = try TestStore.makeContext()
        let record = ReviewRecord(context: context)
        record.id = UUID().uuidString
        record.assetIdentifier = "p"
        record.userAction = ReviewAction.bookmark.rawValue
        record.reviewDate = Calendar.current.date(byAdding: .day, value: -1, to: Date())
        try context.save()

        #expect(try TestStore.makeAnalytics(context: context).currentStreak == 1)
    }

    @Test func reachingAMilestoneIsAnnouncedOnce() throws {
        let analytics = try TestStore.makeAnalytics()
        for index in 0..<99 {
            analytics.record(.bookmark, assetIdentifier: "p\(index)")
        }
        #expect(analytics.newlyEarnedMilestone == nil)

        analytics.record(.bookmark, assetIdentifier: "p99")
        #expect(analytics.newlyEarnedMilestone == .photos100)

        analytics.acknowledgeMilestone()
        analytics.record(.bookmark, assetIdentifier: "p100")
        #expect(analytics.newlyEarnedMilestone == nil)
    }

    @Test func earnedMilestonesAreRememberedAcrossLaunches() throws {
        let context = try TestStore.makeContext()
        let defaults = TestStore.makeDefaults()
        let firstLaunch = try TestStore.makeAnalytics(context: context, defaults: defaults)
        for index in 0..<100 {
            firstLaunch.record(.bookmark, assetIdentifier: "p\(index)")
        }
        firstLaunch.acknowledgeMilestone()

        let nextLaunch = try TestStore.makeAnalytics(context: context, defaults: defaults)
        nextLaunch.record(.bookmark, assetIdentifier: "p100")
        #expect(nextLaunch.newlyEarnedMilestone == nil)
    }
}

// MARK: - Trash

@Suite("Trash staging")
@MainActor
struct TrashTests {
    private func trashedIdentifiers(in context: NSManagedObjectContext) throws -> Set<String> {
        Set(try context.fetch(TrashEntity.fetchRequest()).compactMap(\.assetIdentifier))
    }

    @Test func trashingOnlyRecordsLocally() throws {
        let context = try TestStore.makeContext()
        let trash = CoreDataTrashManager(context: context, photoService: PhotoLibraryService(), syncsWithLibrary: false)
        trash.addToTrash(assetIdentifiers: ["a", "b"])
        trash.addToTrash(assetIdentifier: "a") // duplicates are ignored
        #expect(try trashedIdentifiers(in: context) == ["a", "b"])
    }

    @Test func restoringRemovesOnlyChosenPhotos() throws {
        let context = try TestStore.makeContext()
        let trash = CoreDataTrashManager(context: context, photoService: PhotoLibraryService(), syncsWithLibrary: false)
        trash.addToTrash(assetIdentifiers: ["a", "b", "c"])
        trash.restoreFromTrash(assetIdentifiers: ["a", "c"])
        #expect(try trashedIdentifiers(in: context) == ["b"])

        trash.restoreAll()
        #expect(try trashedIdentifiers(in: context).isEmpty)
    }
}

// MARK: - Haptics

@MainActor
private final class RecordingHapticOutput: HapticOutput {
    var played: [HapticPattern] = []
    var prepared: [[HapticPattern]] = []

    func prepare(_ patterns: [HapticPattern]) { prepared.append(patterns) }
    func play(_ pattern: HapticPattern) { played.append(pattern) }
}

@Suite("Haptics")
@MainActor
struct HapticsTests {
    private func makeHaptics(
        clock: @escaping () -> TimeInterval = { 0 }
    ) -> (Haptics, RecordingHapticOutput) {
        let output = RecordingHapticOutput()
        return (Haptics(output: output, defaults: TestStore.makeDefaults(), clock: clock), output)
    }

    private func sharpest(_ pattern: HapticPattern) -> Float {
        pattern.events.map(\.sharpness).max() ?? 0
    }

    // MARK: Patterns

    @Test func patternsStayShortAndWithinRange() {
        for pattern in HapticPattern.all {
            #expect(pattern.duration <= 0.6, "\(pattern) is too long")
            for event in pattern.events {
                #expect((0...1).contains(event.intensity), "\(pattern)")
                #expect((0...1).contains(event.peakIntensity), "\(pattern)")
                #expect((0...1).contains(event.sharpness), "\(pattern)")
                #expect(event.time >= 0, "\(pattern)")
            }
        }
        // Played on every swipe, so they must be over almost instantly
        for pattern in HapticPattern.deck {
            #expect(pattern.duration <= 0.15, "\(pattern) is too long for the deck")
        }
    }

    @Test func frequentFeedbackStaysGentle() {
        #expect(HapticPattern.skip.peakIntensity <= 0.4)
        #expect(HapticPattern.press.peakIntensity <= 0.4)
        #expect(HapticPattern.release.peakIntensity <= 0.4)
        #expect(HapticPattern.detent(.left).peakIntensity <= 0.6)
        #expect(HapticPattern.detent(.right).peakIntensity <= 0.6)
        // Only a celebration gets near full strength
        for pattern in HapticPattern.all where pattern != .celebrate {
            #expect(pattern.peakIntensity < 0.85, "\(pattern)")
        }
    }

    @Test func trashingIsNotMoreRewardingThanBookmarking() {
        #expect(abs(HapticPattern.trash.peakIntensity - HapticPattern.bookmark.peakIntensity) <= 0.05)
    }

    @Test func feelMatchesTheLook() {
        // Bookmarking is bright and crisp; trashing is round and heavy
        #expect(sharpest(.bookmark) > sharpest(.trash))
        #expect(sharpest(.detent(.right)) > sharpest(.detent(.left)))
    }

    @Test func bookmarkRisesAndUndoFalls() {
        let bookmark = HapticPattern.bookmark.events.map(\.intensity)
        let undo = HapticPattern.undo.events.map(\.intensity)
        #expect(bookmark.count > 1 && bookmark == bookmark.sorted())
        #expect(undo.count > 1 && undo == undo.sorted(by: >))
    }

    @Test func bulkTrashCascadesThenLands() {
        let many = HapticPattern.bulkTrash(count: 40)
        #expect(many.normalized == .bulkTrash(count: 4))

        let cascadeTicks = many.events.filter { $0.kind == .tap && $0.sharpness == 0.65 }
        #expect(cascadeTicks.count == Constants.Haptics.maxCascadeTicks)
        #expect(cascadeTicks.map(\.intensity) == cascadeTicks.map(\.intensity).sorted())

        // It ends with the same thunk as a single trash
        let landing = many.events.suffix(HapticPattern.trash.events.count)
        #expect(landing.map(\.sharpness) == HapticPattern.trash.events.map(\.sharpness))
        #expect(HapticPattern.bulkTrash(count: 1).duration < many.duration)
    }

    @Test func systemFeedbackKeepsItsIOSMeaning() {
        #expect(HapticPattern.system(.selection).fallback == .selection)
        #expect(HapticPattern.system(.success).fallback == .success)
        #expect(HapticPattern.system(.error).fallback == .error)
        #expect(HapticPattern.system(.success).events.isEmpty)
        #expect(HapticPattern.system(.success).isSystem)
        #expect(!HapticPattern.trash.isSystem)
    }

    // MARK: Swipe zones

    @Test func swipeZoneClicksOnceOnTheWayInAndOut() {
        var tracker = SwipeZoneTracker()
        #expect(tracker.update(offset: 50, threshold: 100) == nil)
        #expect(tracker.update(offset: 101, threshold: 100) == .detent(.right))
        #expect(tracker.update(offset: 140, threshold: 100) == nil)
        // Hovering just under the line doesn't chatter
        #expect(tracker.update(offset: 95, threshold: 100) == nil)
        #expect(tracker.update(offset: 101, threshold: 100) == nil)
        #expect(tracker.update(offset: 80, threshold: 100) == .release)
        #expect(tracker.update(offset: 60, threshold: 100) == nil)
    }

    @Test func swipeZoneFollowsDirection() {
        var tracker = SwipeZoneTracker()
        #expect(tracker.update(offset: -120, threshold: 100) == .detent(.left))
        #expect(tracker.update(offset: -20, threshold: 100) == .release)
        #expect(tracker.update(offset: 130, threshold: 100) == .detent(.right))
        // Flung straight across to the other zone
        #expect(tracker.update(offset: -150, threshold: 100) == .detent(.left))

        tracker.reset()
        #expect(tracker.zone == nil)
        #expect(tracker.update(offset: 500, threshold: 0) == nil)
    }

    // MARK: Engine

    @Test func rapidRepeatsOfOnePatternAreDropped() {
        var now: TimeInterval = 0
        let (haptics, output) = makeHaptics { now }

        haptics.play(.trash)
        now = 0.02
        haptics.play(.trash)
        haptics.play(.bookmark)
        now = 0.07
        haptics.play(.trash)

        #expect(output.played == [.trash, .bookmark, .trash])
    }

    @Test func bulkPatternsShareOneCascade() {
        let (haptics, output) = makeHaptics()
        haptics.play(.bulkTrash(count: 12))
        #expect(output.played == [.bulkTrash(count: 4)])
    }

    @Test func prepareWarmsTheDeckPatterns() {
        let (haptics, output) = makeHaptics()
        haptics.prepare()
        #expect(output.prepared == [HapticPattern.deck])
    }

    @Test func turningHapticsOffSilencesEverything() {
        let (haptics, output) = makeHaptics()
        haptics.isEnabled = false
        haptics.prepare()
        haptics.play(.bookmark)
        haptics.play(.system(.success))
        #expect(output.played.isEmpty)
        #expect(output.prepared.isEmpty)
    }

    @Test func theSwitchIsRememberedAndOnByDefault() {
        let defaults = TestStore.makeDefaults()
        let firstLaunch = Haptics(output: RecordingHapticOutput(), defaults: defaults)
        #expect(firstLaunch.isEnabled)
        firstLaunch.isEnabled = false

        let nextLaunch = Haptics(output: RecordingHapticOutput(), defaults: defaults)
        #expect(!nextLaunch.isEnabled)
    }
}
