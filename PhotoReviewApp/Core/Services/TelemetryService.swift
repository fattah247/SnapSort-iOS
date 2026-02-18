//
//  TelemetryService.swift
//  PhotoReviewApp
//

import Foundation
import TelemetryDeck

enum TelemetryService {

    // MARK: - Events

    enum AppEvent {
        case photoReviewed
        case photoDeleted
        case photoBookmarked
        case categorySelected(String)
        case smartCategoryUsed(String)
        case settingChanged(String)
        case sessionTargetReached
        case backgroundAnalysisCompleted

        var name: String {
            switch self {
            case .photoReviewed:              return "photoReviewed"
            case .photoDeleted:               return "photoDeleted"
            case .photoBookmarked:            return "photoBookmarked"
            case .categorySelected:           return "categorySelected"
            case .smartCategoryUsed:          return "smartCategoryUsed"
            case .settingChanged:             return "settingChanged"
            case .sessionTargetReached:       return "sessionTargetReached"
            case .backgroundAnalysisCompleted: return "backgroundAnalysisCompleted"
            }
        }

        var parameters: [String: String] {
            switch self {
            case .categorySelected(let category):
                return ["category": category]
            case .smartCategoryUsed(let category):
                return ["smartCategory": category]
            case .settingChanged(let setting):
                return ["setting": setting]
            default:
                return [:]
            }
        }
    }

    // MARK: - Lifecycle

    static func start() {
        let appID = Constants.Telemetry.appID
        guard appID != "YOUR_TELEMETRY_APP_ID_HERE" else {
            AppLogger.general.warning("TelemetryDeck app ID not configured — skipping initialization")
            return
        }

        let config = TelemetryDeck.Config(appID: appID)
        TelemetryDeck.initialize(config: config)
    }

    // MARK: - Sending

    static func send(_ event: AppEvent) {
        if event.parameters.isEmpty {
            TelemetryDeck.signal(event.name)
        } else {
            TelemetryDeck.signal(event.name, parameters: event.parameters)
        }
    }
}
