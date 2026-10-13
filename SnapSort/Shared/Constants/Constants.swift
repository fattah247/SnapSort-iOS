//
//  Constants.swift
//  SnapSort
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
        static let hapticsEnabled = "hapticsEnabled"
    }

    enum Notifications {
        static let reviewReminderID = "photo-review-reminder"
    }

    enum Widget {
        static let kind = "SnapSortStats"
    }

    enum SharedDefaults {
        static let streak = "widget_streak"
        static let spaceCleared = "widget_spaceCleared"
        static let totalReviewed = "widget_totalReviewed"
        static let totalDeleted = "widget_totalDeleted"
        static let totalBookmarked = "widget_totalBookmarked"
    }

    enum AppGroup {
        static let identifier = "group.com.canoe.snapsort"
    }

    enum DeepLink {
        static let scheme = "photoreviewapp"
        static let host = "photoreview.com"
    }

    enum Haptics {
        /// The same pattern within this window is dropped, so rapid repeats don't blur into a buzz
        static let repeatGuard: TimeInterval = 0.04
        /// A drag leaves a swipe zone only below this fraction of the threshold, so a finger
        /// resting on the line doesn't chatter
        static let zoneExitFraction: CGFloat = 0.85
        /// Bulk trashing ticks once per photo up to this many, then lands with the trash thunk
        static let maxCascadeTicks = 4
    }

    enum PhotoLoading {
        /// Max seconds to wait for a single iCloud image download before giving up
        static let imageLoadTimeout: TimeInterval = 8
        /// How many extra candidates to fetch so we can skip iCloud-only photos
        static let candidateOvershootMultiplier = 3
        /// Number of time buckets to sample from for variety (recent, mid, old, etc.)
        static let randomTimeBuckets = 5
    }

    enum Analysis {
        /// Bump when detection changes — cached results from older versions are discarded
        static let version = 3
        static let versionDefaultsKey = "analysisVersion"

        /// Long side of the image analyzed per photo. Blur is only visible at screen-ish sizes.
        static let imageSize: CGFloat = 1024
        static let maxConcurrentAnalysis = 3
        static let backgroundBatchSize = 20
        static let backgroundBatchDelay: TimeInterval = 0.1
        static let backgroundTaskIdentifier = "com.canoe.snapsort.photoAnalysis"

        // Calibrated on ~160 real photos and blurred/darkened/brightened variants
        /// Re-blur score above which a photo looks soft (sharp originals peaked at 0.578)
        static let blurThreshold: Float = 0.58
        /// A slightly soft photo that the aesthetics model also dislikes is blurry too
        static let softBlurWithLowAestheticsThreshold: Float = 0.52
        static let blurryAestheticsThreshold: Float = -0.5
        static let darkMeanThreshold: Float = 0.14
        static let darkSpreadThreshold: Float = 0.09
        static let blownHighlightThreshold: Float = 0.25
        static let brightMeanThreshold: Float = 0.6
        /// Aesthetics score below which a slightly soft photo is likely a throwaway
        static let lowAestheticsThreshold: Float = -0.6
        static let softBlurThreshold: Float = 0.5

        /// Minimum classifier confidence for scene/pet/food labels
        static let labelConfidence: Float = 0.35
        /// Document labels alone are noisier — photos of paper also trip `isUtility`
        static let documentLabelConfidence: Float = 0.5

        // Similar shots: feature-print distance. Retakes ≤ 0.4, a blurred retake ≤ 0.63,
        // unrelated photos ≥ 0.84 — and only photos taken minutes apart are compared
        static let similarDistanceThreshold: Float = 0.65
        /// Difference-hash fallback: retakes within ~14 of 64 bits, unrelated photos ~30
        static let similarHashThreshold = 14
        /// Only compare photos taken within this many seconds of each other
        static let similarTimeWindow: TimeInterval = 300
        static let similarMaxNeighbors = 30

        /// Videos at least this long count as "long videos"
        static let longVideoDuration: TimeInterval = 60
    }
}
