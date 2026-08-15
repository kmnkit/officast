//
//  MonthMath.swift
//  officast
//
//  Per-month quota arithmetic (SPEC §2, §4.2) and the remaining-workday
//  calendar rule (Codex C6). All pure; `officeDone` and `R` are derived,
//  never stored (single source of truth = the day records).
//

import Foundation

/// Quota arithmetic for a single calendar month.
struct MonthMath: Equatable {
    let requiredOfficeDays: Int   // O — user input
    let officeDone: Int           // derived from check-ins
    let remainingWorkdays: Int    // R — derived from the calendar

    /// Office days still owed: `max(0, O − officeDone)`.
    var oRemain: Int { max(0, requiredOfficeDays - officeDone) }

    /// Days you can still afford to WFH: `R − oRemain`.
    var slack: Int { remainingWorkdays - oRemain }

    /// Fraction of remaining days that must be office. Guards R == 0
    /// (no days left → treat as "must office", ratio 1).
    var officeRatio: Double {
        guard remainingWorkdays > 0 else { return 1 }
        return Double(oRemain) / Double(remainingWorkdays)
    }

    /// Threshold `T = 100 · (1 − officeRatio)` (SPEC §4.2), rounded and clamped
    /// to a valid score `[0, 100]` (ratio > 1 when over-WFH'd would go negative).
    var threshold: Int {
        let raw = Int((100.0 * (1.0 - officeRatio)).rounded())
        return min(100, max(0, raw))
    }
}

/// Computes R — remaining workdays — under the date rules in the plan (Codex C6):
/// the caller chooses `from` (today included before check-in, tomorrow after)
/// and this counts workdays from `from` through month-end inclusive.
enum WorkdayCalculator {

    /// Remaining workdays from `from` (inclusive) through the last day of `from`'s
    /// month, excluding weekly days off and any marked holiday/vacation days.
    ///
    /// - Parameters:
    ///   - weeklyOffDays: ISO weekday numbers off every week (Mon=1 … Sun=7).
    ///   - offDays: specific dates marked holiday/vacation (compared by day).
    static func remainingWorkdays(
        from: Date,
        weeklyOffDays: Set<Int>,
        offDays: Set<Date> = [],
        calendar: Calendar = .current
    ) -> Int {
        workdayDates(from: from, weeklyOffDays: weeklyOffDays, offDays: offDays, calendar: calendar).count
    }

    /// Ordered start-of-day dates that count as workdays from `from` (inclusive)
    /// through `from`'s month-end, excluding weekly days off and marked off days.
    static func workdayDates(
        from: Date,
        weeklyOffDays: Set<Int>,
        offDays: Set<Date> = [],
        calendar: Calendar = .current
    ) -> [Date] {
        guard let monthEnd = lastDayOfMonth(for: from, calendar: calendar) else { return [] }

        let offDayStarts = Set(offDays.map { calendar.startOfDay(for: $0) })
        var dates: [Date] = []
        var cursor = calendar.startOfDay(for: from)
        let end = calendar.startOfDay(for: monthEnd)

        while cursor <= end {
            if !weeklyOffDays.contains(isoWeekday(of: cursor, calendar: calendar)),
               !offDayStarts.contains(cursor) {
                dates.append(cursor)
            }
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }
        return dates
    }

    /// ISO weekday (Mon=1 … Sun=7) from Calendar's 1=Sun … 7=Sat component.
    static func isoWeekday(of date: Date, calendar: Calendar = .current) -> Int {
        let weekday = calendar.component(.weekday, from: date)  // 1=Sun … 7=Sat
        return weekday == 1 ? 7 : weekday - 1
    }

    private static func lastDayOfMonth(for date: Date, calendar: Calendar) -> Date? {
        guard let range = calendar.range(of: .day, in: .month, for: date) else { return nil }
        var components = calendar.dateComponents([.year, .month], from: date)
        components.day = range.upperBound - 1
        return calendar.date(from: components)
    }
}
