//
//  HolidayStore.swift
//  officast
//
//  Reads the device's built-in "Holidays" subscription calendar via EventKit so
//  the month grid can paint region-appropriate public holidays red. iOS keeps the
//  holiday subscription in sync with the user's region, so there is no bundled
//  list to maintain. Full calendar access is required; if denied, holiday lookups
//  return empty and the grid falls back to plain weekday/weekend coloring.
//

import EventKit
import Foundation

@Observable
final class HolidayStore {
    private let store = EKEventStore()
    /// Cached holiday day-starts keyed by "YYYY-MM" so a month is fetched once.
    private var cache: [String: Set<Date>] = [:]

    /// Holiday dates (start-of-day) that fall within `month`. Requests calendar
    /// access on first use; returns an empty set if access is denied or fails.
    func load(month: Date, calendar: Calendar = .current) async -> Set<Date> {
        // Under UI test, skip EventKit so no calendar-permission dialog appears.
        guard !UITestConfig.isActive else { return [] }

        let key = DateKeys.monthKey(month, calendar: calendar)
        if let cached = cache[key] { return cached }

        guard await ensureAccess() else { return [] }

        let dates = holidayDates(in: month, calendar: calendar)
        cache[key] = dates
        return dates
    }

    /// Requests full access to events if not already authorized.
    private func ensureAccess() async -> Bool {
        switch EKEventStore.authorizationStatus(for: .event) {
        case .fullAccess:
            return true
        case .notDetermined:
            return (try? await store.requestFullAccessToEvents()) ?? false
        default:
            return false
        }
    }

    /// All-day holiday events for `month`, normalized to start-of-day.
    private func holidayDates(in month: Date, calendar: Calendar) -> Set<Date> {
        guard let interval = calendar.dateInterval(of: .month, for: month) else { return [] }

        let holidayCalendars = store.calendars(for: .event).filter {
            $0.type == .subscription && !$0.allowsContentModifications
        }
        guard !holidayCalendars.isEmpty else { return [] }

        let predicate = store.predicateForEvents(
            withStart: interval.start, end: interval.end, calendars: holidayCalendars
        )
        let events = store.events(matching: predicate).filter(\.isAllDay)
        return Set(events.map { calendar.startOfDay(for: $0.startDate) })
    }
}
