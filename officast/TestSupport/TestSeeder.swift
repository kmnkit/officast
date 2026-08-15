//
//  TestSeeder.swift
//  officast
//
//  Puts the app into a known state for UI tests: a clean UserDefaults domain,
//  seeded settings + month record + day records, an optional weather cache, and
//  an optional pending check-in. Runs only under `UITEST`.
//

import Foundation
import SwiftData

enum TestSeeder {

    /// Wipe prior UI-test state and apply the requested seed. The in-memory
    /// SwiftData store already starts empty each launch; only UserDefaults needs
    /// an explicit reset because it persists across launches.
    static func seed(container: ModelContainer, calendar: Calendar = .current, now: Date = AppClock.now) {
        guard UITestConfig.isActive else { return }
        resetDefaults()

        let settings = AppSettings()
        applySettings(settings)

        let context = ModelContext(container)
        let month = makeMonth(context: context, calendar: calendar, now: now)
        let officeSeeded = seedDays(month: month, context: context, calendar: calendar, now: now)
        applyQuota(to: month, settings: settings, officeSeeded: officeSeeded, calendar: calendar, now: now)
        seedCacheIfNeeded(context: context, calendar: calendar, now: now)
        try? context.save()

        seedPendingCheckIn(calendar: calendar, now: now)
    }

    // MARK: - UserDefaults

    private static func resetDefaults() {
        if let bundleId = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: bundleId)
        }
    }

    private static func applySettings(_ settings: AppSettings) {
        // Seoul home; no separate office (evening leg falls back to home) so a
        // single stubbed forecast drives every leg.
        settings.homeName = "Test Home"
        settings.homeLat = 37.5665
        settings.homeLng = 126.9780
        settings.hasOfficeLocation = false
        settings.departureHour = 8
        settings.returnHour = 19
        settings.notifyHour = 21
        settings.weeklyOffDays = [6, 7]
        settings.hasCompletedOnboarding = UITestConfig.isOnboarded
    }

    // MARK: - Month record + quota

    private static func makeMonth(context: ModelContext, calendar: Calendar, now: Date) -> MonthRecord {
        let monthKey = DateKeys.monthKey(now, calendar: calendar)
        if let existing = MonthRepository.fetch(monthKey: monthKey, context: context) {
            return existing
        }
        let record = MonthRecord(yearMonth: monthKey, requiredOfficeDays: 0)
        context.insert(record)
        return record
    }

    private static func applyQuota(
        to month: MonthRecord, settings: AppSettings,
        officeSeeded: Int, calendar: Calendar, now: Date
    ) {
        let remaining = WorkdayCalculator.remainingWorkdays(
            from: calendar.startOfDay(for: now),
            weeklyOffDays: settings.weeklyOffDays, calendar: calendar)

        switch UITestConfig.quotaMode {
        case .explicit:
            month.priorOfficeCount = UITestConfig.priorCountOverride ?? 0
            month.requiredOfficeDays = UITestConfig.requiredDaysOverride ?? 10
        case .slackNegative:
            month.priorOfficeCount = 0
            // Owe more than remain, no matter the date → slack < 0.
            month.requiredOfficeDays = officeSeeded + remaining + 3
        case .balanced:
            month.priorOfficeCount = 0
            // Owe exactly one office day: the threshold sits high (100·(1−1/R)),
            // so a great day (100) clears it and a grim day (23) doesn't, while
            // E7's "today among the top-N needed" can never pull the single worst
            // visible day into office. Deterministic for any R ≥ 2, regardless of
            // date or how many future workdays fall inside the forecast horizon.
            month.requiredOfficeDays = officeSeeded + 1
        }
    }

    // MARK: - Day records

    /// Insert seeded day records on distinct dates within the current month,
    /// linked to `month`. Returns how many count as office (for quota bookkeeping).
    private static func seedDays(month: MonthRecord, context: ModelContext, calendar: Calendar, now: Date) -> Int {
        let specs = UITestConfig.seedDays
        guard !specs.isEmpty else { return 0 }

        var comps = calendar.dateComponents([.year, .month], from: now)
        var officeCount = 0
        for (index, spec) in specs.enumerated() {
            comps.day = index + 1
            guard let date = calendar.date(from: comps) else { continue }
            let record = DayRecord(date: calendar.startOfDay(for: date),
                                   status: spec.status,
                                   weatherScoreSnapshot: spec.snapshot)
            record.month = month
            month.days.append(record)
            context.insert(record)
            if spec.status.countsAsOffice { officeCount += 1 }
        }
        return officeCount
    }

    // MARK: - Weather cache (offline scenario)

    private static func seedCacheIfNeeded(context: ModelContext, calendar: Calendar, now: Date) {
        guard UITestConfig.weatherScenario == .fetchFailCached else { return }
        let key = DateKeys.dayKey(now, calendar: calendar)
        let hours = (6...20).map {
            WeatherHour(hour: $0, popPct: 0, mmPerH: 0, snow: false, windMs: 1, tempC: 20)
        }
        context.insert(WeatherCache(date: key, hourly: hours, fetchedAt: now))
    }

    // MARK: - Pending check-in

    private static func seedPendingCheckIn(calendar: Calendar, now: Date) {
        guard let status = UITestConfig.pendingCheckIn else { return }
        PendingCheckIn.store(date: calendar.startOfDay(for: now), status: status)
    }
}
