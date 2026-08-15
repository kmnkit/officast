//
//  WeatherCache.swift
//  officast
//
//  Locally cached hourly forecast for one day (SPEC §7). The hourly array is
//  stored as encoded JSON so SwiftData keeps a single column; the typed
//  accessor decodes on read.
//

import Foundation
import SwiftData

@Model
final class WeatherCache {
    /// Start-of-day for the forecast date.
    @Attribute(.unique) var date: Date

    /// Encoded `[WeatherHour]`.
    var hourlyData: Data

    /// When this forecast was fetched (freshness check).
    var fetchedAt: Date

    init(date: Date, hourly: [WeatherHour], fetchedAt: Date) {
        self.date = date
        self.hourlyData = (try? JSONEncoder().encode(hourly)) ?? Data()
        self.fetchedAt = fetchedAt
    }

    /// Decoded hourly forecast (empty if the blob is corrupt).
    var hourly: [WeatherHour] {
        (try? JSONDecoder().decode([WeatherHour].self, from: hourlyData)) ?? []
    }
}
