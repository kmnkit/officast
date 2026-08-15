//
//  AnalyticsLogger.swift
//  officast
//
//  Central place for the app's custom Firebase Analytics events. Keeps event and
//  parameter names in one spot and confines the FirebaseAnalytics import so call
//  sites stay UI-focused.
//

import FirebaseAnalytics
import Foundation

enum AnalyticsLogger {

    /// User set or changed a day's attendance status from the calendar.
    static func logAttendanceStatus(_ status: AttendanceStatus) {
        Analytics.logEvent("log_attendance_status", parameters: ["status": status.rawValue])
    }

    /// User finished onboarding and entered the app.
    static func completeOnboarding() {
        Analytics.logEvent("complete_onboarding", parameters: nil)
    }

    /// User tapped a check-in action on the morning notification.
    static func notificationCheckInTapped(_ status: AttendanceStatus) {
        Analytics.logEvent("notification_checkin_tapped", parameters: ["status": status.rawValue])
    }
}
