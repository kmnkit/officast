//
//  WeatherSnapshotTests.swift
//  officastTests
//
//  P1b: check-in weather snapshot computed from cache and stored on office/WFH
//  days only. Uses an in-memory SwiftData container.
//

import Foundation
import SwiftData
import Testing
@testable import officast

@MainActor
struct WeatherSnapshotTests {

    private func makeContext() throws -> ModelContext {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: MonthRecord.self, DayRecord.self, WeatherCache.self, configurations: config)
        return ModelContext(container)
    }

    private func makeSettings() -> AppSettings {
        let suite = "test.snapshot.\(UUID().uuidString)"
        return AppSettings(defaults: UserDefaults(suiteName: suite)!)
    }

    private func rainyDate() -> Date {
        var c = DateComponents(); c.year = 2026; c.month = 8; c.day = 20
        return Calendar.current.date(from: c)!
    }

    /// Cache a rainy day (all legs pop 80 → score 60) keyed like the app does.
    private func seedRainyCache(_ date: Date, context: ModelContext) {
        let key = DateKeys.dayKey(date)
        let hours = [8, 12, 19].map {
            WeatherHour(hour: $0, popPct: 80, mmPerH: 0, snow: false, windMs: 3, tempC: 20)
        }
        context.insert(WeatherCache(date: key, hourly: hours, fetchedAt: date))
        try? context.save()
    }

    @Test func scoreReadsBestFromCache() throws {
        let context = try makeContext()
        let settings = makeSettings()
        let date = rainyDate()
        seedRainyCache(date, context: context)

        let score = WeatherSnapshot.score(for: date, settings: settings, context: context)
        #expect(score == 60)   // all legs pop 80 → 60
    }

    @Test func scoreNilWithoutCache() throws {
        let context = try makeContext()
        let settings = makeSettings()
        #expect(WeatherSnapshot.score(for: rainyDate(), settings: settings, context: context) == nil)
    }

    @Test func snapshotStoredOnWFHDay() throws {
        let context = try makeContext()
        let settings = makeSettings()
        let date = rainyDate()
        seedRainyCache(date, context: context)

        let snapshot = WeatherSnapshot.score(for: date, settings: settings, context: context)
        MonthRepository.setStatus(date: date, status: .wfh, requiredOfficeDays: 10,
                                  weatherScoreSnapshot: snapshot, context: context)

        let monthKey = DateKeys.monthKey(date)
        let record = MonthRepository.fetch(monthKey: monthKey, context: context)?.days.first
        #expect(record?.status == .wfh)
        #expect(record?.weatherScoreSnapshot == 60)
    }

    @Test func snapshotNotStoredOnHoliday() throws {
        let context = try makeContext()
        let date = rainyDate()

        MonthRepository.setStatus(date: date, status: .holiday, requiredOfficeDays: 10,
                                  weatherScoreSnapshot: 60, context: context)

        let monthKey = DateKeys.monthKey(date)
        let record = MonthRepository.fetch(monthKey: monthKey, context: context)?.days.first
        #expect(record?.status == .holiday)
        #expect(record?.weatherScoreSnapshot == nil)
    }
}
