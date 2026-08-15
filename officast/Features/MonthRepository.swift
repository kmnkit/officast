//
//  MonthRepository.swift
//  officast
//
//  Fetch-or-create the current MonthRecord and upsert day check-ins. Keeps
//  SwiftData access in one place so views stay declarative.
//

import Foundation
import SwiftData

enum MonthRepository {

    static func fetch(monthKey: String, context: ModelContext) -> MonthRecord? {
        let descriptor = FetchDescriptor<MonthRecord>(predicate: #Predicate { $0.yearMonth == monthKey })
        return try? context.fetch(descriptor).first
    }

    /// Ensure a month record exists; create it with `requiredOfficeDays` if new.
    @discardableResult
    static func upsert(monthKey: String, requiredOfficeDays: Int, context: ModelContext) -> MonthRecord {
        if let existing = fetch(monthKey: monthKey, context: context) {
            existing.requiredOfficeDays = requiredOfficeDays
            return existing
        }
        let record = MonthRecord(yearMonth: monthKey, requiredOfficeDays: requiredOfficeDays)
        context.insert(record)
        try? context.save()
        return record
    }

    /// Set (or clear) a day's status. `.none` removes the record.
    /// `weatherScoreSnapshot` is stored on office/WFH days when available (P1b);
    /// nil leaves any existing snapshot untouched.
    static func setStatus(
        date: Date, status: AttendanceStatus,
        requiredOfficeDays: Int, weatherScoreSnapshot: Int? = nil,
        context: ModelContext, calendar: Calendar = .current
    ) {
        let day = calendar.startOfDay(for: date)
        let monthKey = DateKeys.monthKey(date, calendar: calendar)
        let month = upsert(monthKey: monthKey, requiredOfficeDays: requiredOfficeDays, context: context)

        if let existing = month.days.first(where: { calendar.startOfDay(for: $0.date) == day }) {
            if status == .none {
                context.delete(existing)
            } else {
                existing.status = status
                applySnapshot(weatherScoreSnapshot, to: existing, status: status)
            }
        } else if status != .none {
            let record = DayRecord(date: day, status: status)
            record.month = month
            applySnapshot(weatherScoreSnapshot, to: record, status: status)
            month.days.append(record)
            context.insert(record)
        }
        try? context.save()
    }

    /// Store the snapshot only for commute-relevant days (office/WFH), and only
    /// when a fresh value is available (nil never clears an existing snapshot).
    private static func applySnapshot(_ snapshot: Int?, to record: DayRecord, status: AttendanceStatus) {
        guard let snapshot else { return }
        let commuteRelevant = status.countsAsOffice || status == .wfh
        if commuteRelevant { record.weatherScoreSnapshot = snapshot }
    }

    /// Apply a pending notification check-in, seeding O from the existing month
    /// (or a sensible default) so a record always exists. Captures the weather
    /// snapshot from the cache when available (P1b).
    static func applyPendingCheckIn(settings: AppSettings, context: ModelContext, calendar: Calendar = .current) {
        guard let pending = PendingCheckIn.take() else { return }
        let monthKey = DateKeys.monthKey(pending.date, calendar: calendar)
        let required = fetch(monthKey: monthKey, context: context)?.requiredOfficeDays ?? 0
        let snapshot = WeatherSnapshot.score(for: pending.date, settings: settings, context: context, calendar: calendar)
        setStatus(date: pending.date, status: pending.status,
                  requiredOfficeDays: required, weatherScoreSnapshot: snapshot,
                  context: context, calendar: calendar)
    }
}
