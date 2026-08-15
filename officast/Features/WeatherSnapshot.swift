//
//  WeatherSnapshot.swift
//  officast
//
//  Computes the best commute score for a date from the cached forecast, taken
//  at check-in time and stored on the DayRecord for the P4 monthly report
//  ("days you WFH'd when rain was forecast"). Best-effort: nil when no cache.
//

import Foundation
import SwiftData

enum WeatherSnapshot {

    /// Best commute score for `date` from the cached forecast, or nil if none.
    /// Uses the cached home forecast for all legs (office cache isn't stored;
    /// the snapshot is a coarse "how rough was the commute" metric).
    static func score(
        for date: Date,
        settings: AppSettings,
        context: ModelContext,
        calendar: Calendar = .current
    ) -> Int? {
        let key = DateKeys.dayKey(date, calendar: calendar)
        let descriptor = FetchDescriptor<WeatherCache>(predicate: #Predicate { $0.date == key })
        guard let cache = try? context.fetch(descriptor).first, !cache.hourly.isEmpty else { return nil }
        return CommuteForecast.dayScore(
            home: cache.hourly, office: cache.hourly,
            departureHour: settings.departureHour, returnHour: settings.returnHour).score.best
    }
}
