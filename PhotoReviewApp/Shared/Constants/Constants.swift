//
//  Constants.swift
//  PhotoReviewApp
//
//  Created by Muhammad Abdul Fattah on 04/02/25.
//
import Foundation

enum Constants {
    enum UserDefaultsKeys {
        static let isNotificationsEnabled = "isNotificationsEnabled"
        static let notificationTime = "notificationTime"
        static let repeatInterval = "repeatInterval"
        static let storageTarget = "storageTarget"
        static let sortOption = "sortOption"
        static let showDeletionConfirmation = "showDeletionConfirmation"
        static let selectedWeeklyDays = "selectedWeeklyDays"
        static let selectedMonthlyDay = "selectedMonthlyDay"
    }

    enum Notifications {
        static let reviewReminderID = "photo-review-reminder"
    }

    enum Widget {
        static let kind = "PhotoReviewStats"
    }

    enum SharedDefaults {
        static let streak = "widget_streak"
        static let storageSaved = "widget_storageSaved"
        static let totalReviewed = "widget_totalReviewed"
        static let totalDeleted = "widget_totalDeleted"
        static let totalBookmarked = "widget_totalBookmarked"
    }

    enum AppGroup {
        static let identifier = "group.com.fatarc.PhotoReviewApp"
    }

    enum DeepLink {
        static let scheme = "photoreviewapp"
        static let host = "photoreview.com"
    }

    enum Sentry {
        static let dsn = "YOUR_SENTRY_DSN_HERE"  // Replace with your Sentry DSN
    }

    enum Telemetry {
        static let appID = "YOUR_TELEMETRY_APP_ID_HERE"  // Replace with your TelemetryDeck app ID
    }

    enum Analysis {
        static let thumbnailSize: CGFloat = 300
        static let maxConcurrentAnalysis = 3
        static let backgroundBatchSize = 20
        static let backgroundBatchDelay: TimeInterval = 0.1
        static let blurThreshold: Float = 0.7
        static let darkThreshold: Float = 0.15
        static let brightThreshold: Float = 0.92
        static let duplicateDistanceThreshold: Float = 0.3
        static let backgroundTaskIdentifier = "com.fatarc.PhotoReviewApp.photoAnalysis"
    }
}
