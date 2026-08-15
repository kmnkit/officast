//
//  WeatherService.swift
//  officast
//
//  Open-Meteo hourly forecast client (E5). The protocol lets tests inject a
//  mock (Eng Review D3). API contract per plan / Codex C15:
//    wind_speed_unit=ms, timezone=auto, precipitation is the prior-hour sum.
//

import Foundation

/// Abstraction over the weather provider so consumers and tests don't depend
/// on the concrete network client.
protocol WeatherFetching {
    /// Fetch hourly forecast for `forecastDays` days from today, bucketed by day.
    /// Keys are UTC start-of-day for the local forecast date (see mapping note).
    func fetchDailyHourly(
        latitude: Double,
        longitude: Double,
        forecastDays: Int
    ) async throws -> [Date: [WeatherHour]]
}

enum WeatherServiceError: Error {
    case badResponse
}

struct OpenMeteoClient: WeatherFetching {

    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func fetchDailyHourly(
        latitude: Double,
        longitude: Double,
        forecastDays: Int
    ) async throws -> [Date: [WeatherHour]] {
        var components = URLComponents(string: "https://api.open-meteo.com/v1/forecast")!
        components.queryItems = [
            .init(name: "latitude", value: String(latitude)),
            .init(name: "longitude", value: String(longitude)),
            .init(name: "hourly", value: "precipitation_probability,precipitation,snowfall,wind_speed_10m,temperature_2m"),
            .init(name: "wind_speed_unit", value: "ms"),   // default is km/h (C15)
            .init(name: "timezone", value: "auto"),         // DST handled server-side (C15)
            .init(name: "forecast_days", value: String(forecastDays)),
        ]
        guard let url = components.url else { throw WeatherServiceError.badResponse }

        let (data, response) = try await session.data(from: url)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw WeatherServiceError.badResponse
        }
        let decoded = try JSONDecoder().decode(OpenMeteoResponse.self, from: data)
        return Self.hourlyByDate(from: decoded)
    }

    // MARK: - Pure mapping (testable without network)

    struct OpenMeteoResponse: Decodable {
        struct Hourly: Decodable {
            let time: [String]
            let precipitation_probability: [Int?]?
            let precipitation: [Double?]?
            let snowfall: [Double?]?
            let wind_speed_10m: [Double?]?
            let temperature_2m: [Double?]?
        }
        let hourly: Hourly
    }

    /// Map a decoded response into per-day `[WeatherHour]`. Time strings are
    /// already localized (`timezone=auto`), so we key by the calendar-date part
    /// and take the hour from the time part — no timezone math, DST-safe.
    static func hourlyByDate(from response: OpenMeteoResponse) -> [Date: [WeatherHour]] {
        let h = response.hourly
        var result: [Date: [WeatherHour]] = [:]

        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(identifier: "UTC")!
        let dayFormatter = DateFormatter()
        dayFormatter.calendar = utc
        dayFormatter.timeZone = utc.timeZone
        dayFormatter.dateFormat = "yyyy-MM-dd"

        for (index, time) in h.time.enumerated() {
            // "YYYY-MM-DDTHH:MM"
            guard time.count >= 13,
                  let tIndex = time.firstIndex(of: "T") else { continue }
            let datePart = String(time[time.startIndex..<tIndex])
            let hourStart = time.index(after: tIndex)
            let hourEnd = time.index(hourStart, offsetBy: 2)
            guard let hour = Int(time[hourStart..<hourEnd]),
                  let day = dayFormatter.date(from: datePart) else { continue }

            let popPct: Int = value(h.precipitation_probability, index) ?? 0
            let mmPerH: Double = value(h.precipitation, index) ?? 0
            let snowfall: Double = value(h.snowfall, index) ?? 0
            let windMs: Double = value(h.wind_speed_10m, index) ?? 0
            let tempC: Double = value(h.temperature_2m, index) ?? 0

            let weatherHour = WeatherHour(
                hour: hour,
                popPct: popPct,
                mmPerH: mmPerH,
                snow: snowfall > 0,
                windMs: windMs,
                tempC: tempC
            )
            result[day, default: []].append(weatherHour)
        }
        return result
    }

    /// Safely read `array[index]`, flattening the provider's `[T?]?` into `T?`.
    private static func value<T>(_ array: [T?]?, _ index: Int) -> T? {
        guard let array, array.indices.contains(index) else { return nil }
        return array[index]
    }
}
