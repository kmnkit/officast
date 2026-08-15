//
//  PendingCheckInTests.swift
//  officastTests
//
//  Integration coverage for the notification check-in application path
//  (MonthRepository.applyPendingCheckIn). A pending check-in — the record a
//  notification action leaves behind — is applied to SwiftData when the app next
//  becomes active. This is verified here rather than in the UI suite because
//  XCUITest can neither fire a real notification action nor reliably drive the
//  background→foreground transition without relaunching (which drops the
//  hermetic launch environment).
//

import Foundation
import SwiftData
import Testing
@testable import officast

@MainActor
struct PendingCheckInTests {

    private func makeContext() throws -> ModelContext {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: MonthRecord.self, DayRecord.self, WeatherCache.self, configurations: config)
        return ModelContext(container)
    }

    private func makeSettings() -> AppSettings {
        AppSettings(defaults: UserDefaults(suiteName: "test.pending.\(UUID().uuidString)")!)
    }

    private func monday() -> Date {
        var c = DateComponents(); c.year = 2026; c.month = 8; c.day = 17
        return Calendar.current.date(from: c)!
    }

    @Test func appliesPendingOfficeCheckIn() throws {
        let context = try makeContext()
        let settings = makeSettings()
        let date = monday()
        let defaults = UserDefaults(suiteName: "test.pending.checkin.\(UUID().uuidString)")!

        MonthRepository.upsert(monthKey: DateKeys.monthKey(date), requiredOfficeDays: 10, context: context)
        PendingCheckIn.store(date: date, status: .officeFull, defaults: defaults)

        MonthRepository.applyPendingCheckIn(settings: settings, context: context, defaults: defaults)

        let month = MonthRepository.fetch(monthKey: DateKeys.monthKey(date), context: context)
        #expect(month?.officeDone == 1)
        #expect(month?.days.first?.status == .officeFull)
        // The pending record is consumed exactly once.
        #expect(PendingCheckIn.take(defaults: defaults) == nil)
    }

    @Test func noPendingIsANoOp() throws {
        let context = try makeContext()
        let settings = makeSettings()
        let defaults = UserDefaults(suiteName: "test.pending.empty.\(UUID().uuidString)")!

        MonthRepository.applyPendingCheckIn(settings: settings, context: context, defaults: defaults)

        let month = MonthRepository.fetch(monthKey: DateKeys.monthKey(monday()), context: context)
        #expect(month == nil)
    }
}
