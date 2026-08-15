//
//  DayRecord.swift
//  officast
//
//  A single logged day (SPEC §7). The weather-score snapshot field is part of
//  the schema now (added in P1a to avoid a later migration) but only written
//  starting in P1b, for the P4 monthly report.
//

import Foundation
import SwiftData

@Model
final class DayRecord {
    /// Start-of-day for the logged date.
    var date: Date

    /// Persisted AttendanceStatus raw value (SPEC §7 string enum).
    var statusRaw: String

    /// Snapshot of the day's best commute score at check-in time (P1b).
    /// nil until P1b starts writing it.
    var weatherScoreSnapshot: Int?

    var month: MonthRecord?

    init(date: Date, status: AttendanceStatus, weatherScoreSnapshot: Int? = nil) {
        self.date = date
        self.statusRaw = status.rawValue
        self.weatherScoreSnapshot = weatherScoreSnapshot
    }

    /// Typed accessor over the persisted raw value.
    var status: AttendanceStatus {
        get { AttendanceStatus(rawValue: statusRaw) ?? .none }
        set { statusRaw = newValue.rawValue }
    }
}
