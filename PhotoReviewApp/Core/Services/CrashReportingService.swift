//
//  CrashReportingService.swift
//  PhotoReviewApp
//

import Foundation
import Sentry

enum CrashReportingService {

    static func start() {
        let dsn = Constants.Sentry.dsn
        guard dsn != "YOUR_SENTRY_DSN_HERE" else {
            AppLogger.general.warning("Sentry DSN not configured — skipping initialization")
            return
        }

        SentrySDK.start { options in
            options.dsn = dsn

            #if DEBUG
            options.environment = "development"
            options.tracesSampleRate = 1.0
            options.debug = true
            #else
            options.environment = "production"
            options.tracesSampleRate = 0.2
            #endif

            options.enableAutoSessionTracking = true
            options.attachScreenshot = true
            options.enableMetricKit = true
        }
    }

    static func capture(_ error: Error) {
        SentrySDK.capture(error: error)
    }

    static func addBreadcrumb(category: String, message: String) {
        let crumb = Breadcrumb(level: .info, category: category)
        crumb.message = message
        SentrySDK.addBreadcrumb(crumb)
    }
}
