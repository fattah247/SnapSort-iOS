//
//  AppStateManager.swift
//  PhotoReviewApp
//
//  Created by Muhammad Abdul Fattah on 04/02/25.
//
import Photos
import CoreData
import SwiftUI
import OSLog

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
        
        switch components.path {
        case "/review":
            if let id = components.queryItems?.first(where: { $0.name == "id" })?.value {
                deepLinkTarget = .review(id)
                activeTab = .review
            }
        case "/trash":
            if let id = components.queryItems?.first(where: { $0.name == "id" })?.value {
                deepLinkTarget = .trash(id)
                activeTab = .trash
            }
        case "/stats":
            if let id = components.queryItems?.first(where: { $0.name == "id" })?.value {
                deepLinkTarget = .stats(id)
                activeTab = .stats
            }
        case "/bookmarks":
            if let id = components.queryItems?.first(where: { $0.name == "id" })?.value {
                deepLinkTarget = .bookmarks(id)
                activeTab = .bookmarks
            }
        case "/settings":
            if let id = components.queryItems?.first(where: { $0.name == "id" })?.value {
                deepLinkTarget = .settings(id)
                activeTab = .settings
            }
        default: break
        }
    }
    
    func configureServices(
        photoService: any PhotoLibraryServiceProtocol,
        notificationService: any NotificationServiceProtocol
    ) {
        notificationService.setAuthorizationChangeHandler { [weak self] authorized in
            self?.handleNotificationAuthorizationChange(authorized: authorized)
        }
    }
    
    private func handleNotificationAuthorizationChange(authorized: Bool) {
        if !authorized {
            DispatchQueue.main.async { [weak self] in
                self?.activeTab = .settings
            }
        }
    }
}
