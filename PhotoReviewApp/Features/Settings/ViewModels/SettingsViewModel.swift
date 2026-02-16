//
//  SettingsViewModel.swift
//  PhotoReviewApp
//
//  Created by Muhammad Abdul Fattah on 03/02/25.
//
import SwiftUI
import Photos
import CoreData
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

@MainActor
final class SettingsViewModel: ObservableObject {
    @Published var isNotificationsEnabled = false
    @Published var notificationTime = Date()
    @Published var repeatInterval: RepeatInterval = .daily
    @Published var storageTarget: Int64 = 100 * 1024 * 1024  // 100 MB default
    @Published var sortOption: PhotoSortOption = .random
    @Published var showDeletionConfirmation = true
    
    // Added properties to support weekly and monthly selections:
    @Published var selectedWeeklyDays: [Weekday] = []
    @Published var selectedMonthlyDay: Int = 1
    
    private var settingsStore: any SettingsStoreProtocol
    private let trashManager: any TrashManagerProtocol
    private let notificationService: any NotificationServiceProtocol
    
    var hasUnsavedChanges: Bool {
        settingsStore.isNotificationsEnabled     != isNotificationsEnabled
        || settingsStore.notificationTime         != notificationTime
        || settingsStore.repeatInterval           != repeatInterval
        || settingsStore.storageTarget             != storageTarget
        || settingsStore.sortOption               != sortOption
        || settingsStore.showDeletionConfirmation != showDeletionConfirmation
        || settingsStore.selectedWeeklyDays       != selectedWeeklyDays
        || settingsStore.selectedMonthlyDay       != selectedMonthlyDay
    }
    
    init(settingsStore: any SettingsStoreProtocol,
         trashManager: any TrashManagerProtocol,
         notificationService: any NotificationServiceProtocol) {
        self.settingsStore = settingsStore
        self.trashManager = trashManager
        self.notificationService = notificationService
        loadSettings()
    }
    
    func loadSettings() {
        settingsStore.loadSettings()
        isNotificationsEnabled = settingsStore.isNotificationsEnabled
        notificationTime = settingsStore.notificationTime
        repeatInterval = settingsStore.repeatInterval
        storageTarget = settingsStore.storageTarget
        sortOption = settingsStore.sortOption
        showDeletionConfirmation = settingsStore.showDeletionConfirmation
        // Optionally load these if your store supports them:
        selectedWeeklyDays = settingsStore.selectedWeeklyDays
        selectedMonthlyDay = settingsStore.selectedMonthlyDay
    }
    
    func saveSettings() {
        settingsStore.isNotificationsEnabled = isNotificationsEnabled
        settingsStore.notificationTime = notificationTime
        settingsStore.repeatInterval = repeatInterval
        settingsStore.storageTarget = storageTarget
        settingsStore.sortOption = sortOption
        settingsStore.showDeletionConfirmation = showDeletionConfirmation
        // Optionally save the new properties if needed:
        settingsStore.selectedWeeklyDays = selectedWeeklyDays
        settingsStore.selectedMonthlyDay = selectedMonthlyDay
        settingsStore.saveSettings()
        
        if isNotificationsEnabled {
            notificationService.scheduleNotifications(
                time: notificationTime,
                repeatInterval: repeatInterval
            )
        } else {
            notificationService.cancelAllNotifications()
        }
    }
    
    func emptyTrash() {
        trashManager.emptyTrash()
    }
}

