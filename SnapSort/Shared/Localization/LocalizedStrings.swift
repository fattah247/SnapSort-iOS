//
//  LocalizedStrings.swift
//  SnapSort
//
//  Created by Muhammad Abdul Fattah on 05/02/25.
//
import Foundation

enum LocalizedStrings {
    // Notifications
    static let notificationTitle = tr("notifications.title", "A few photos to sort")
    static let notificationBody = tr("notifications.body", "Take a minute to clear out photos you don't need.")

    private static func tr(_ key: String, _ fallback: String) -> String {
        NSLocalizedString(key, value: fallback, comment: "")
    }
}
