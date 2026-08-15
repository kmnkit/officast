//
//  NotificationScheduler.swift
//  officast
//
//  Daily 21:00 local reminder with one-tap check-in actions (SPEC §5). Local
//  only — no APNs. The action a user taps is recorded as a pending check-in
//  (UserDefaults) and applied to SwiftData when the app next becomes active,
//  which avoids opening a second ModelContainer from the notification handler.
//

import Foundation
import UserNotifications

enum NotificationScheduler {

    static let categoryId = "DAILY_CHECKIN"
    static let requestIdentifier = "daily-checkin"

    /// Action identifiers map 1:1 to the office/WFH statuses.
    static let actionStatuses: [(id: String, status: AttendanceStatus)] = [
        ("CHECKIN_OFFICE_FULL", .officeFull),
        ("CHECKIN_OFFICE_AM", .officeAM),
        ("CHECKIN_OFFICE_PM", .officePM),
        ("CHECKIN_WFH", .wfh),
    ]

    static func requestAuthorization() async -> Bool {
        (try? await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    static func registerCategory() {
        let actions = actionStatuses.map { entry in
            UNNotificationAction(identifier: entry.id,
                                 title: RecommendationPresentation.statusLabel(entry.status),
                                 options: [])
        }
        let category = UNNotificationCategory(
            identifier: categoryId, actions: actions,
            intentIdentifiers: [], options: [])
        UNUserNotificationCenter.current().setNotificationCategories([category])
    }

    /// Schedule the repeating daily reminder at `hour`:00.
    static func scheduleDaily(hour: Int) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [requestIdentifier])

        let content = UNMutableNotificationContent()
        content.title = String(localized: "notif.title")
        content.body = String(localized: "notif.body")
        content.categoryIdentifier = categoryId
        content.sound = .default

        var components = DateComponents()
        components.hour = hour
        components.minute = 0
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        center.add(UNNotificationRequest(identifier: requestIdentifier, content: content, trigger: trigger))
    }

    static func status(forActionId id: String) -> AttendanceStatus? {
        actionStatuses.first { $0.id == id }?.status
    }
}

/// A check-in chosen from a notification action, pending application to SwiftData.
enum PendingCheckIn {
    private static let dateKey = "pendingCheckInDate"
    private static let statusKey = "pendingCheckInStatus"

    static func store(date: Date, status: AttendanceStatus, defaults: UserDefaults = .standard) {
        defaults.set(date.timeIntervalSince1970, forKey: dateKey)
        defaults.set(status.rawValue, forKey: statusKey)
    }

    static func take(defaults: UserDefaults = .standard) -> (date: Date, status: AttendanceStatus)? {
        guard let raw = defaults.string(forKey: statusKey),
              let status = AttendanceStatus(rawValue: raw),
              defaults.object(forKey: dateKey) != nil else { return nil }
        let date = Date(timeIntervalSince1970: defaults.double(forKey: dateKey))
        defaults.removeObject(forKey: dateKey)
        defaults.removeObject(forKey: statusKey)
        return (date, status)
    }
}
