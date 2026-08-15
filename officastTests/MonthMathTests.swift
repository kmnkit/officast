//
//  MonthMathTests.swift
//  officastTests
//
//  Quota arithmetic (SPEC §2, §4.2) and remaining-workday calendar rule (C6).
//

import Foundation
import Testing
@testable import officast

struct MonthMathTests {

    @Test func derivesRemainSlackAndThreshold() {
        let m = MonthMath(requiredOfficeDays: 12, officeDone: 4, remainingWorkdays: 15)
        #expect(m.oRemain == 8)
        #expect(m.slack == 7)
        #expect(m.threshold == 47)   // 100 * (1 − 8/15) = 46.67 → 47
    }

    @Test func slackNegativeWhenOverWFHd() {
        let m = MonthMath(requiredOfficeDays: 12, officeDone: 2, remainingWorkdays: 5)
        #expect(m.oRemain == 10)
        #expect(m.slack == -5)
        #expect(m.threshold == 0)    // ratio clamps behavior: oRemain>R → ratio>1 → T<0? see below
    }

    @Test func slackZeroForcesOfficeEveryDay() {
        let m = MonthMath(requiredOfficeDays: 10, officeDone: 0, remainingWorkdays: 10)
        #expect(m.slack == 0)
        #expect(m.threshold == 0)    // ratio 1 → T 0
    }

    @Test func oRemainFloorsAtZeroWhenQuotaMet() {
        let m = MonthMath(requiredOfficeDays: 5, officeDone: 8, remainingWorkdays: 10)
        #expect(m.oRemain == 0)
        #expect(m.slack == 10)
        #expect(m.threshold == 100)  // ratio 0 → T 100 (only a perfect day is worth it)
    }

    @Test func guardsRemainingWorkdaysZero() {
        let m = MonthMath(requiredOfficeDays: 5, officeDone: 3, remainingWorkdays: 0)
        #expect(m.officeRatio == 1)
        #expect(m.threshold == 0)
    }

    // MARK: - WorkdayCalculator (fixed calendar, UTC to avoid DST offsets)

    private var utcCalendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal
    }

    private func date(_ y: Int, _ mo: Int, _ d: Int) -> Date {
        var c = DateComponents()
        c.year = y; c.month = mo; c.day = d
        return utcCalendar.date(from: c)!
    }

    @Test func countsWeekdaysAcrossFullMonth() {
        // August 2026 starts on a Saturday; 21 weekdays, 10 weekend days.
        let r = WorkdayCalculator.remainingWorkdays(
            from: date(2026, 8, 1), weeklyOffDays: [6, 7], calendar: utcCalendar)
        #expect(r == 21)
    }

    @Test func countsFromMidMonthThroughEnd() {
        // 2026-08-31 is a Monday → one workday left.
        let r = WorkdayCalculator.remainingWorkdays(
            from: date(2026, 8, 31), weeklyOffDays: [6, 7], calendar: utcCalendar)
        #expect(r == 1)
    }

    @Test func excludesMarkedOffDays() {
        // From Monday Aug 31, but Aug 31 is marked holiday → zero.
        let r = WorkdayCalculator.remainingWorkdays(
            from: date(2026, 8, 31), weeklyOffDays: [6, 7],
            offDays: [date(2026, 8, 31)], calendar: utcCalendar)
        #expect(r == 0)
    }

    @Test func isoWeekdayConversion() {
        #expect(WorkdayCalculator.isoWeekday(of: date(2026, 8, 1), calendar: utcCalendar) == 6) // Sat
        #expect(WorkdayCalculator.isoWeekday(of: date(2026, 8, 3), calendar: utcCalendar) == 1) // Mon
    }
}
