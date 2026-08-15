//
//  WeatherServiceTests.swift
//  officastTests
//
//  Pure mapping of an Open-Meteo response into per-day [WeatherHour].
//  No network — decodes a fixed JSON blob (E5 / Codex C15).
//

import Foundation
import Testing
@testable import officast

struct WeatherServiceTests {

    private let sampleJSON = """
    {
      "hourly": {
        "time": ["2026-08-15T08:00", "2026-08-15T09:00", "2026-08-16T08:00"],
        "precipitation_probability": [80, null, 10],
        "precipitation": [3.2, 0.0, 0.0],
        "snowfall": [0.0, 0.0, 1.5],
        "wind_speed_10m": [4.0, 5.0, 8.0],
        "temperature_2m": [31.0, 30.0, 2.0]
      }
    }
    """

    private func decodedByDate() throws -> [Date: [WeatherHour]] {
        let data = Data(sampleJSON.utf8)
        let response = try JSONDecoder().decode(OpenMeteoClient.OpenMeteoResponse.self, from: data)
        return OpenMeteoClient.hourlyByDate(from: response)
    }

    @Test func bucketsHoursByDay() throws {
        let byDate = try decodedByDate()
        #expect(byDate.count == 2)
        let hours = byDate.values.flatMap { $0 }
        #expect(hours.count == 3)
    }

    @Test func mapsFieldsAndHours() throws {
        let byDate = try decodedByDate()
        let day15 = byDate.values.first { $0.contains { $0.tempC == 31 } }!
        let morning = day15.first { $0.hour == 8 }!
        #expect(morning.popPct == 80)
        #expect(morning.mmPerH == 3.2)
        #expect(!morning.snow)
        #expect(morning.windMs == 4.0)
        #expect(morning.tempC == 31.0)
    }

    @Test func nullProbabilityBecomesZero() throws {
        let byDate = try decodedByDate()
        let nine = byDate.values.flatMap { $0 }.first { $0.hour == 9 }!
        #expect(nine.popPct == 0)   // null → 0
    }

    @Test func snowfallSetsSnowFlag() throws {
        let byDate = try decodedByDate()
        let snowy = byDate.values.flatMap { $0 }.first { $0.snow }!
        #expect(snowy.hour == 8)
        #expect(snowy.tempC == 2.0)
    }
}
