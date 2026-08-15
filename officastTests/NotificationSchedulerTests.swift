//
//  NotificationSchedulerTests.swift
//  officastTests
//
//  Pure morning-reminder timing (P2 task 14).
//

import Foundation
import Testing
@testable import officast

struct NotificationSchedulerTests {

    private var utc: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }

    private func date(_ y: Int, _ mo: Int, _ d: Int, _ h: Int, _ mi: Int) -> Date {
        var c = DateComponents(); c.year = y; c.month = mo; c.day = d; c.hour = h; c.minute = mi
        return utc.date(from: c)!
    }

    @Test func beforeLeadTimeSchedulesToday() {
        // Departure 08:00, lead 30 → 07:30. Now 06:00 → today 07:30.
        let now = date(2026, 8, 20, 6, 0)
        let result = NotificationScheduler.nextMorningReminderDate(departureHour: 8, now: now, calendar: utc)
        #expect(result == date(2026, 8, 20, 7, 30))
    }

    @Test func afterLeadTimeRollsToTomorrow() {
        // Now 08:00 is past today's 07:30 → tomorrow 07:30.
        let now = date(2026, 8, 20, 8, 0)
        let result = NotificationScheduler.nextMorningReminderDate(departureHour: 8, now: now, calendar: utc)
        #expect(result == date(2026, 8, 21, 7, 30))
    }

    @Test func midnightDepartureHasNoReminder() {
        let now = date(2026, 8, 20, 6, 0)
        #expect(NotificationScheduler.nextMorningReminderDate(departureHour: 0, now: now, calendar: utc) == nil)
    }
}
