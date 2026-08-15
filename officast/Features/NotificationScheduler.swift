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
    static let morningIdentifier = "morning-reminder"

    /// Minutes before departure the morning reminder fires.
    static let morningLeadMinutes = 30

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

    /// The next departure-minus-lead datetime at or after `now` for `departureHour`.
    /// Returns nil for a midnight departure (no sensible lead time).
    static func nextMorningReminderDate(
        departureHour: Int, now: Date = Date(), calendar: Calendar = .current
    ) -> Date? {
        guard departureHour >= 1 else { return nil }
        var components = DateComponents()
        components.hour = departureHour
        components.minute = 0
        guard let departureToday = calendar.nextDate(
            after: now.addingTimeInterval(-1), matching: components,
            matchingPolicy: .nextTime) else { return nil }
        let reminder = departureToday.addingTimeInterval(TimeInterval(-morningLeadMinutes * 60))
        // If today's lead time already passed, roll to tomorrow's departure.
        if reminder <= now {
            guard let tomorrowDeparture = calendar.date(byAdding: .day, value: 1, to: departureToday) else { return nil }
            return tomorrowDeparture.addingTimeInterval(TimeInterval(-morningLeadMinutes * 60))
        }
        return reminder
    }

    /// Schedule the one-shot morning reminder at `date` with a concrete body
    /// (E2, best-effort — only registered while the app is in use).
    static func scheduleMorningReminder(at date: Date, body: String, calendar: Calendar = .current) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [morningIdentifier])

        let content = UNMutableNotificationContent()
        content.title = String(localized: "notif.morning.title")
        content.body = body
        content.sound = .default

        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        center.add(UNNotificationRequest(identifier: morningIdentifier, content: content, trigger: trigger))
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
