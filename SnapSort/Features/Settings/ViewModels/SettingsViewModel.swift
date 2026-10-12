//
//  SettingsViewModel.swift
//  SnapSort
//
//  Created by Muhammad Abdul Fattah on 03/02/25.
//
import SwiftUI
import UserNotifications
import OSLog

protocol SettingsStoreProtocol {
    var isNotificationsEnabled: Bool { get set }
    var notificationTime: Date { get set }
    var repeatInterval: RepeatInterval { get set }
    var storageTarget: Int64 { get set }
    var sortOption: PhotoSortOption { get set }
    var showDeletionConfirmation: Bool { get set }
    var selectedWeeklyDays: [Weekday]  { get set }
    var selectedMonthlyDay: Int { get set }
    func loadSettings()
    func saveSettings()
}

/// Settings apply immediately — there is no separate save step.
@MainActor
final class SettingsViewModel: ObservableObject {
    @Published private(set) var isNotificationsEnabled = false { didSet { persist() } }
    @Published var notificationTime = Date() { didSet { persist() } }
    @Published var repeatInterval: RepeatInterval = .daily { didSet { persist() } }
    @Published var storageTarget: Int64 = 100_000_000 { didSet { persist() } }
    @Published var sortOption: PhotoSortOption = .random { didSet { persist() } }
    @Published var showDeletionConfirmation = false { didSet { persist() } }
    @Published var selectedWeeklyDays: [Weekday] = [] { didSet { persist() } }
    @Published var selectedMonthlyDay: Int = 1 { didSet { persist() } }

    /// True when the user has turned notifications off for the app in iOS Settings
    @Published private(set) var notificationsDenied = false

    nonisolated static let monthDayRange = 1...28
    // Decimal megabytes, matching how file sizes are displayed
    nonisolated static let storageTargetRange: ClosedRange<Int64> = 50_000_000...1_000_000_000
    nonisolated static let storageTargetStep: Int64 = 50_000_000

    private var settingsStore: any SettingsStoreProtocol
    private let notificationService: any NotificationServiceProtocol
    private var isLoading = false

    init(settingsStore: any SettingsStoreProtocol,
         notificationService: any NotificationServiceProtocol) {
        self.settingsStore = settingsStore
        self.notificationService = notificationService
        loadSettings()
    }

    func loadSettings() {
        isLoading = true
        defer { isLoading = false }
        settingsStore.loadSettings()
        isNotificationsEnabled = settingsStore.isNotificationsEnabled
        notificationTime = settingsStore.notificationTime
        repeatInterval = settingsStore.repeatInterval
        storageTarget = Self.snappedStorageTarget(settingsStore.storageTarget)
        sortOption = settingsStore.sortOption
        showDeletionConfirmation = settingsStore.showDeletionConfirmation
        selectedWeeklyDays = settingsStore.selectedWeeklyDays
        // Days 29–31 don't exist in every month, so reminders would silently skip
        selectedMonthlyDay = min(max(settingsStore.selectedMonthlyDay, Self.monthDayRange.lowerBound), Self.monthDayRange.upperBound)
    }

    /// Older builds stored binary megabytes (e.g. 104,857,600) — snap to the stepper grid
    nonisolated static func snappedStorageTarget(_ value: Int64) -> Int64 {
        let steps = (Double(value) / Double(storageTargetStep)).rounded()
        let snapped = Int64(steps) * storageTargetStep
        return min(max(snapped, storageTargetRange.lowerBound), storageTargetRange.upperBound)
    }

    // MARK: - Reminders

    /// Turns reminders on (asking for permission if needed) or off.
    func setRemindersEnabled(_ enabled: Bool) async {
        guard enabled else {
            isNotificationsEnabled = false
            return
        }

        switch await notificationService.authorizationStatus() {
        case .notDetermined:
            let granted = await notificationService.requestAuthorization()
            notificationsDenied = !granted
            isNotificationsEnabled = granted
        case .denied:
            notificationsDenied = true
            isNotificationsEnabled = false
        default:
            notificationsDenied = false
            isNotificationsEnabled = true
        }
    }

    /// Re-checks system permission, e.g. when returning from iOS Settings.
    func refreshNotificationStatus() async {
        let denied = await notificationService.authorizationStatus() == .denied
        notificationsDenied = denied
        if denied && isNotificationsEnabled {
            isNotificationsEnabled = false
        }
    }

    // MARK: - Persistence

    private func persist() {
        guard !isLoading else { return }

        settingsStore.isNotificationsEnabled = isNotificationsEnabled
        settingsStore.notificationTime = notificationTime
        settingsStore.repeatInterval = repeatInterval
        settingsStore.storageTarget = storageTarget
        settingsStore.sortOption = sortOption
        settingsStore.showDeletionConfirmation = showDeletionConfirmation
        settingsStore.selectedWeeklyDays = selectedWeeklyDays
        settingsStore.selectedMonthlyDay = selectedMonthlyDay
        settingsStore.saveSettings()

        if isNotificationsEnabled {
            notificationService.scheduleNotifications(
                time: notificationTime,
                repeatInterval: repeatInterval,
                weekdays: selectedWeeklyDays,
                monthDay: selectedMonthlyDay
            )
        } else {
            notificationService.cancelAllNotifications()
        }
    }
}
