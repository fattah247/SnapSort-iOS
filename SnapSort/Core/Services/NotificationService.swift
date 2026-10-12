//
//  NotificationService.swift
//  SnapSort
//
//  Created by Muhammad Abdul Fattah on 04/02/25.
//
import UserNotifications
import SwiftUI
import OSLog

protocol NotificationServiceProtocol: ObservableObject {
    func requestAuthorization() async -> Bool
    func authorizationStatus() async -> UNAuthorizationStatus
    func scheduleNotifications(
        time: Date,
        repeatInterval: RepeatInterval,
        weekdays: [Weekday],
        monthDay: Int
    )
    func cancelAllNotifications()
}

final class NotificationService: NotificationServiceProtocol {
    private let center = UNUserNotificationCenter.current()

    func requestAuthorization() async -> Bool {
        let result = try? await center.requestAuthorization(options: [.alert, .sound, .badge])
        return result ?? false
    }

    func authorizationStatus() async -> UNAuthorizationStatus {
        await center.notificationSettings().authorizationStatus
    }

    func scheduleNotifications(
        time: Date,
        repeatInterval: RepeatInterval,
        weekdays: [Weekday],
        monthDay: Int
    ) {
        center.removeAllPendingNotificationRequests()

        let content = UNMutableNotificationContent()
        content.title = LocalizedStrings.notificationTitle
        content.body = LocalizedStrings.notificationBody
        content.sound = .default

        let timeComponents = Calendar.current.dateComponents([.hour, .minute], from: time)

        for (index, components) in triggerComponents(
            base: timeComponents,
            repeatInterval: repeatInterval,
            weekdays: weekdays,
            monthDay: monthDay
        ).enumerated() {
            let trigger = UNCalendarNotificationTrigger(
                dateMatching: components,
                repeats: repeatInterval != .never
            )
            let request = UNNotificationRequest(
                identifier: "\(Constants.Notifications.reviewReminderID)-\(index)",
                content: content,
                trigger: trigger
            )
            center.add(request) { error in
                if let error {
                    AppLogger.general.error("Failed to schedule reminder: \(error.localizedDescription, privacy: .public)")
                }
            }
        }
    }

    func cancelAllNotifications() {
        center.removeAllPendingNotificationRequests()
    }

    /// One trigger per firing pattern — weekly reminders need one per weekday.
    func triggerComponents(
        base: DateComponents,
        repeatInterval: RepeatInterval,
        weekdays: [Weekday],
        monthDay: Int
    ) -> [DateComponents] {
        switch repeatInterval {
        case .daily, .never:
            return [base]
        case .weekly:
            let days = weekdays.isEmpty
                ? [Weekday(rawValue: Calendar.current.component(.weekday, from: Date())) ?? .mon]
                : weekdays
            return days.map { day in
                var components = base
                components.weekday = day.rawValue
                return components
            }
        case .monthly:
            var components = base
            components.day = monthDay
            return [components]
        }
    }
}
