//
//  Logger.swift
//  PhotoReviewApp
//
//  Created by Muhammad Abdul Fattah on 04/02/25.
//
import Foundation
import os.log

struct AppLogger {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.photoReviewApp"

    static let general = Logger(
        subsystem: subsystem,
        category: "General"
    )

    static let coreData = Logger(
        subsystem: subsystem,
        category: "CoreData"
    )

    static let security = Logger(
        subsystem: subsystem,
        category: "Security"
    )

    static let analysis = Logger(
        subsystem: subsystem,
        category: "Analysis"
    )
}
