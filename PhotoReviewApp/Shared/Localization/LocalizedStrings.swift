//
//  LocalizedStrings.swift
//  PhotoReviewApp
//
//  Created by Muhammad Abdul Fattah on 05/02/25.
//
import Foundation

enum LocalizedStrings {
    // Common
    static let cancel = tr("common.cancel", "Cancel")
    static let ok = tr("common.ok", "OK")
    static let retry = tr("common.retry", "Retry")
    static let delete = tr("common.delete", "Delete")
    // Notifications
    static let notificationTitle = tr("notifications.title", "Review Reminder")
    static let notificationBody = tr("notifications.body", "Time to review your photos!")
    
    // Settings
    static let settingsTitle = tr("settings.title", "Settings")
    static let notificationsSection = tr("settings.notifications", "Notifications")
    static let photoSelectionSection = tr("settings.photo_selection", "Photo Selection")
    
    // Error Messages
    static let genericError = tr("errors.generic", "An error occurred")
    static let photoAccessDenied = tr("errors.photo_access", "Photo library access required")
    
    private static func tr(_ key: String, _ fallback: String) -> String {
        NSLocalizedString(key, value: fallback, comment: "")
    }
}
