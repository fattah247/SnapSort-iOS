//
//  NotificationService.swift
//  PhotoReviewApp
//
//  Created by Muhammad Abdul Fattah on 04/02/25.
//
import UserNotifications
import Photos
import CoreData
import SwiftUI
import OSLog

protocol NotificationServiceProtocol: ObservableObject {
    func setAuthorizationChangeHandler(_ handler: @escaping (Bool) -> Void)
    func requestAuthorization() async -> Bool
    func scheduleNotifications(time: Date, repeatInterval: RepeatInterval)
    func cancelAllNotifications()
}

final class NotificationService: NotificationServiceProtocol {
    private let center = UNUserNotificationCenter.current()
    private var authObserver: NSObjectProtocol?

    deinit {
        if let authObserver {
            NotificationCenter.default.removeObserver(authObserver)
        }
    }

    func requestAuthorization() async -> Bool {
        let result = try? await center.requestAuthorization(options: [.alert, .sound])
        return result ?? false
    }

    func scheduleNotifications(time: Date, repeatInterval: RepeatInterval) {
        center.removeAllPendingNotificationRequests()

        let content = UNMutableNotificationContent()
        content.title = "Photo Review Time"
        content.body = "It's time to review your memories!"
        content.sound = .default

        let components = Calendar.current.dateComponents([.hour, .minute], from: time)
        let trigger = UNCalendarNotificationTrigger(
            dateMatching: components,
            repeats: repeatInterval != .never
        )

        let request = UNNotificationRequest(
            identifier: "photo-review-reminder",
            content: content,
            trigger: trigger
        )

        center.add(request)
    }

    func cancelAllNotifications() {
        center.removeAllPendingNotificationRequests()
    }

    func setAuthorizationChangeHandler(_ handler: @escaping (Bool) -> Void) {
        // Remove previous observer to prevent stacking
        if let authObserver {
            NotificationCenter.default.removeObserver(authObserver)
        }
        authObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { _ in
            handler(PHPhotoLibrary.authorizationStatus() == .authorized)
        }
    }
}
