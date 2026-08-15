//
//  UITestConfig.swift
//  officast
//
//  Reads the UI-test launch environment ONCE and exposes it as typed values.
//  Everything here is inert in production: `isActive` is false unless the test
//  runner sets `UITEST=1`, so no production code path changes without the flag.
//

import Foundation

/// How the seeder should choose this month's quota (`O`).
enum UITestQuotaMode {
    /// Adaptive: pick `O` from the real remaining-workday count so the decision
    /// threshold lands near 50 with positive slack — keeps weather-driven
    /// recommendations deterministic regardless of the calendar date.
    case balanced
    /// Force slack < 0 (quota unreachable) to surface the warning state.
    case slackNegative
    /// Use the exact `requiredDays` / `priorCount` overrides verbatim.
    case explicit
}

enum UITestConfig {

    private static let env = ProcessInfo.processInfo.environment

    /// Master switch. All other hooks are gated behind this.
    static var isActive: Bool { env["UITEST"] == "1" }

    /// Start already onboarded (default) or at the onboarding screen.
    static var isOnboarded: Bool { env["UITEST_ONBOARDED"] != "0" }

    static var weatherScenario: WeatherScenario? {
        WeatherScenario(rawValue: env["UITEST_WEATHER"] ?? "")
    }

    /// Pins "today" (see AppClock) to a fixed date, e.g. `UITEST_TODAY=2026-06-15`.
    static var fixedToday: Date? {
        guard isActive, let raw = env["UITEST_TODAY"] else { return nil }
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: raw)
    }

    static var quotaMode: UITestQuotaMode {
        switch env["UITEST_QUOTA"] {
        case "slackNegative": return .slackNegative
        case "explicit": return .explicit
        default: return .balanced
        }
    }

    static var requiredDaysOverride: Int? { env["UITEST_REQUIRED_DAYS"].flatMap(Int.init) }
    static var priorCountOverride: Int? { env["UITEST_PRIOR_COUNT"].flatMap(Int.init) }

    /// A check-in to seed as pending, exercising the apply-on-foreground path.
    static var pendingCheckIn: AttendanceStatus? {
        switch env["UITEST_PENDING_CHECKIN"] {
        case "office": return .officeFull
        case "office_am": return .officeAM
        case "office_pm": return .officePM
        case "wfh": return .wfh
        default: return nil
        }
    }

    /// Day records to seed for the current month, as `status:snapshot` pairs
    /// (snapshot optional), e.g. `office_full:80,wfh:20,wfh:90`. Consecutive
    /// weekdays starting at the 1st are used so weekends don't collide.
    static var seedDays: [(status: AttendanceStatus, snapshot: Int?)] {
        guard let raw = env["UITEST_SEED_DAYS"], !raw.isEmpty else { return [] }
        return raw.split(separator: ",").compactMap { entry in
            let parts = entry.split(separator: ":", omittingEmptySubsequences: false)
            guard let status = AttendanceStatus(rawValue: String(parts[0])) else { return nil }
            let snapshot = parts.count > 1 ? Int(parts[1]) : nil
            return (status, snapshot)
        }
    }
}
