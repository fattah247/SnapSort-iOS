//
//  UserDefaultSettingsStore.swift
//  PhotoReviewApp
//
//  Created by Muhammad Abdul Fattah on 05/02/25.
//
import Foundation

final class UserDefaultsSettingsStore: SettingsStoreProtocol {
    private let defaults = UserDefaults.standard
    
    var isNotificationsEnabled: Bool {
        get { defaults.bool(forKey: Constants.UserDefaultsKeys.isNotificationsEnabled) }
        set { defaults.set(newValue, forKey: Constants.UserDefaultsKeys.isNotificationsEnabled) }
    }
    
    var notificationTime: Date {
        get { defaults.object(forKey: Constants.UserDefaultsKeys.notificationTime) as? Date ?? Date() }
        set { defaults.set(newValue, forKey: Constants.UserDefaultsKeys.notificationTime) }
    }
    
    var repeatInterval: RepeatInterval {
        get {
            guard let rawValue = defaults.string(forKey: Constants.UserDefaultsKeys.repeatInterval) else {
                return .daily
            }
            return RepeatInterval(rawValue: rawValue) ?? .daily
        }
        set { defaults.set(newValue.rawValue, forKey: Constants.UserDefaultsKeys.repeatInterval) }
    }
    
    var storageTarget: Int64 {
        get {
            let value = defaults.integer(forKey: Constants.UserDefaultsKeys.storageTarget)
            // Default to 100 MB if not set
            return value == 0 ? (100 * 1024 * 1024) : Int64(value)
        }
        set { defaults.set(Int(newValue), forKey: Constants.UserDefaultsKeys.storageTarget) }
    }
    
    var sortOption: PhotoSortOption {
        get {
            guard let rawValue = defaults.string(forKey: Constants.UserDefaultsKeys.sortOption) else {
                return .random
            }
            return PhotoSortOption(rawValue: rawValue) ?? .random
        }
        set { defaults.set(newValue.rawValue, forKey: Constants.UserDefaultsKeys.sortOption) }
    }
    
    var showDeletionConfirmation: Bool {
        get { defaults.bool(forKey: Constants.UserDefaultsKeys.showDeletionConfirmation) }
        set { defaults.set(newValue, forKey: Constants.UserDefaultsKeys.showDeletionConfirmation) }
    }
    
    // New properties for weekly and monthly selections
    var selectedWeeklyDays: [Weekday] {
        get {
            let rawValues = defaults.array(forKey: Constants.UserDefaultsKeys.selectedWeeklyDays) as? [Int] ?? []
            return rawValues.compactMap { Weekday(rawValue: $0) }
        }
        set {
            let rawValues = newValue.map { $0.rawValue }
            defaults.set(rawValues, forKey: Constants.UserDefaultsKeys.selectedWeeklyDays)
        }
    }
    
    var selectedMonthlyDay: Int {
        get {
            let day = defaults.integer(forKey: Constants.UserDefaultsKeys.selectedMonthlyDay)
            return day == 0 ? 1 : day  // Default to 1 if not set
        }
        set {
            defaults.set(newValue, forKey: Constants.UserDefaultsKeys.selectedMonthlyDay)
        }
    }
    
    func loadSettings() {
        // Settings are loaded via the computed properties
    }
    
    func saveSettings() {
        defaults.synchronize()
    }
}
