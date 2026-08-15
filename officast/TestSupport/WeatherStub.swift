//
//  WeatherStub.swift
//  officast
//
//  Deterministic `WeatherFetching` used only under `UITEST`. Canned forecasts
//  are calibrated against CommuteScorer/DecisionEngine so each scenario forces a
//  specific, date-independent recommendation (paired with the seeder's balanced
//  quota, which pins the threshold near 50).
//

import Foundation

/// The weather situations a UI test can request via `UITEST_WEATHER`.
enum WeatherScenario: String {
    case sunny                          // every leg great → Office (full day)
    case rainyToday = "rainy_today"     // today grim, later days great → WFH
    case amClearPmRain = "am_clear_pm_rain" // clear morning, wet evening → Office (AM only)
    case fetchFail = "fetch_fail"       // throws, no cache → error + Retry
    case fetchFailCached = "fetch_fail_cached" // throws, cache present → offline banner
}

/// Selects the real client in production and the stub only under UI test.
enum WeatherClientFactory {
    static func make() -> WeatherFetching {
        if UITestConfig.isActive, let scenario = UITestConfig.weatherScenario {
            return WeatherStub(scenario: scenario)
        }
        return OpenMeteoClient()
    }
}

struct WeatherStub: WeatherFetching {
    let scenario: WeatherScenario
    var now: Date = AppClock.now
    var calendar: Calendar = .current

    /// Clear/mild/calm → scores 100.
    private static let good = WeatherHour(hour: 0, popPct: 0, mmPerH: 0, snow: false, windMs: 1, tempC: 20)
    /// Heavy rain + strong wind + cold → scores ~23 (well below the ~50 threshold).
    private static let bad = WeatherHour(hour: 0, popPct: 100, mmPerH: 10, snow: false, windMs: 15, tempC: 1)

    func fetchDailyHourly(
        latitude: Double,
        longitude: Double,
        forecastDays: Int
    ) async throws -> [Date: [WeatherHour]] {
        switch scenario {
        case .fetchFail, .fetchFailCached:
            throw WeatherServiceError.badResponse
        case .sunny:
            return days(forecastDays) { _, _ in Self.good }
        case .rainyToday:
            return days(forecastDays) { dayIndex, _ in dayIndex == 0 ? Self.bad : Self.good }
        case .amClearPmRain:
            // Today: clear through midday (covers morning + midday legs), wet
            // evening (covers the return leg). Future days clear.
            return days(forecastDays) { dayIndex, hour in
                guard dayIndex == 0 else { return Self.good }
                return hour <= 13 ? Self.good : Self.bad
            }
        }
    }

    /// Build `count` days of 24 hourly entries keyed exactly as the app looks
    /// them up (`DateKeys.dayKey`), choosing each hour via `pick(dayIndex, hour)`.
    private func days(_ count: Int, pick: (_ dayIndex: Int, _ hour: Int) -> WeatherHour) -> [Date: [WeatherHour]] {
        var result: [Date: [WeatherHour]] = [:]
        let today = calendar.startOfDay(for: now)
        for dayIndex in 0..<count {
            guard let date = calendar.date(byAdding: .day, value: dayIndex, to: today) else { continue }
            let key = DateKeys.dayKey(date, calendar: calendar)
            result[key] = (0..<24).map { hour in
                let template = pick(dayIndex, hour)
                return WeatherHour(hour: hour, popPct: template.popPct, mmPerH: template.mmPerH,
                                   snow: template.snow, windMs: template.windMs, tempC: template.tempC)
            }
        }
        return result
    }
}
