//
//  MonthRecord.swift
//  officast
//
//  Per-month quota record (SPEC §7). `officeDone` and `R` are derived at read
//  time from the day records — never stored (single source of truth = `days`).
//

import Foundation
import SwiftData

@Model
final class MonthRecord {
    /// "YYYY-MM" — one record per calendar month.
    @Attribute(.unique) var yearMonth: String

    /// O — required office days this month (user input).
    var requiredOfficeDays: Int

    /// Office days already attended before install / first log this month —
    /// entered at onboarding so mid-month users start with correct progress (C13).
    var priorOfficeCount: Int

    @Relationship(deleteRule: .cascade, inverse: \DayRecord.month)
    var days: [DayRecord]

    init(yearMonth: String, requiredOfficeDays: Int, priorOfficeCount: Int = 0, days: [DayRecord] = []) {
        self.yearMonth = yearMonth
        self.requiredOfficeDays = requiredOfficeDays
        self.priorOfficeCount = priorOfficeCount
        self.days = days
    }

    /// Office days done this month: logged full/AM/PM plus the onboarding seed.
    var officeDone: Int {
        days.filter { $0.status.countsAsOffice }.count + priorOfficeCount
    }
}
