//
//  AppStateManager.swift
//  SnapSort
//
//  Created by Muhammad Abdul Fattah on 04/02/25.
//
import SwiftUI

final class AppStateManager: ObservableObject {
    @Published var activeTab: AppTab = .review
    @Published var deepLinkTarget: DeepLinkTarget?

    enum AppTab: CaseIterable {
        case review, stats, bookmarks, trash, settings
    }

    enum DeepLinkTarget: Equatable {
        case review(String)
        case trash(String)
        case stats(String)
        case bookmarks(String)
        case settings(String)
    }

    func handleDeepLink(_ url: URL) {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: true) else { return }
        let id = components.queryItems?.first(where: { $0.name == "id" })?.value

        switch components.path {
        case "/review":
            activeTab = .review
            deepLinkTarget = id.map(DeepLinkTarget.review)
        case "/trash":
            activeTab = .trash
            deepLinkTarget = id.map(DeepLinkTarget.trash)
        case "/stats":
            activeTab = .stats
            deepLinkTarget = id.map(DeepLinkTarget.stats)
        case "/bookmarks":
            activeTab = .bookmarks
            deepLinkTarget = id.map(DeepLinkTarget.bookmarks)
        case "/settings":
            activeTab = .settings
            deepLinkTarget = id.map(DeepLinkTarget.settings)
        default:
            break
        }
    }
}
