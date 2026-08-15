//
//  DateKeys.swift
//  officast
//
//  Bridges local calendar dates to the forecast cache's day keys. Open-Meteo
//  (timezone=auto) returns localized time strings; `hourlyByDate` keys each day
//  by the UTC midnight of that calendar date, so lookups must use the same key.
//

import Foundation

enum DateKeys {

    static let utc: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }()

    /// Forecast-bucket key for a date: UTC midnight of its y-m-d in `calendar`.
    static func dayKey(_ date: Date, calendar: Calendar = .current) -> Date {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return utc.date(from: DateComponents(year: c.year, month: c.month, day: c.day)) ?? date
    }

    /// "YYYY-MM" month key for a date.
    static func monthKey(_ date: Date, calendar: Calendar = .current) -> String {
        let c = calendar.dateComponents([.year, .month], from: date)
        return String(format: "%04d-%02d", c.year ?? 0, c.month ?? 0)
    }
}
