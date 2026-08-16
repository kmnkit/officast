//
//  AppNotificationDelegate.swift
//  officast
//
//  Captures notification check-in actions and records them as a pending
//  check-in (applied to SwiftData when the app next becomes active).
//

import Foundation
import UserNotifications

final class AppNotificationDelegate: NSObject, UNUserNotificationCenterDelegate {

    /// Show the reminder even while the app is in the foreground.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }

    /// Record the tapped action; RootView applies it on next active.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        guard let status = NotificationScheduler.status(forActionId: response.actionIdentifier) else { return }
        PendingCheckIn.store(date: Date(), status: status)
    }
}
