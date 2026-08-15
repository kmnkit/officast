//
//  CommuteModels.swift
//  officast
//
//  Domain value types for the commute-scoring / decision engine.
//  Pure data — no UI, no persistence, no I/O.
//

import Foundation

/// One hour of forecast at a single commute leg.
/// `mmPerH` is the precipitation intensity for that hour (0 when dry).
/// `Codable` so the data layer can cache it directly (no separate DTO).
struct WeatherHour: Equatable, Codable {
    let hour: Int        // 0...23, local time
    let popPct: Int      // precipitation probability, 0...100
    let mmPerH: Double    // precipitation intensity, mm/h (0 when none)
    let snow: Bool
    let windMs: Double    // wind speed, m/s
    let tempC: Double

    init(hour: Int, popPct: Int, mmPerH: Double, snow: Bool, windMs: Double, tempC: Double) {
        self.hour = hour
        self.popPct = popPct
        self.mmPerH = mmPerH
        self.snow = snow
        self.windMs = windMs
        self.tempC = tempC
    }
}

/// The three commute legs scored by the engine (SPEC §3).
enum CommuteLeg: CaseIterable {
    case morningOut     // leaving home at departure time
    case midday         // changeover leg used by half-days (~12:00)
    case eveningHome    // leaving the office at return time
}

/// An attendance option the engine can recommend (SPEC §4.1).
enum AttendanceOption: Equatable {
    case fullDay
    case amOnly
    case pmOnly
}

/// A logged/stored day status. Persisted as the raw string (SPEC §7).
enum AttendanceStatus: String, Codable, CaseIterable {
    case officeFull = "office_full"
    case officeAM = "office_am"
    case officePM = "office_pm"
    case wfh
    case holiday
    case vacation
    case none

    /// Full / AM / PM each count as one office day toward the quota.
    var countsAsOffice: Bool {
        switch self {
        case .officeFull, .officeAM, .officePM: return true
        default: return false
        }
    }
}

/// The engine's recommendation for a day.
enum Recommendation: Equatable {
    case office(AttendanceOption)
    case wfh
}

/// Why the engine reached its recommendation. UI maps these to l10n strings later.
enum DecisionReason: Equatable {
    case slackNegative          // quota already unreachable — office every remaining day
    case slackZero              // every remaining workday must be office
    case goodDaySpend           // bestScore >= T — spend an office day on a good day
    case saveForWorse           // bestScore < T — save it for a worse day
    case futureBetterDaysAhead  // threshold said office, but better days are coming → WFH
    case futureTodayIsBest      // threshold said WFH, but today is among the best left → office
}

/// The per-day trio of option scores, derived from the three leg scores.
struct DayScore: Equatable {
    let fullDay: Int
    let amOnly: Int
    let pmOnly: Int

    /// argmax over the three options; ties prefer fullDay, then amOnly.
    var bestOption: AttendanceOption {
        if fullDay >= amOnly && fullDay >= pmOnly { return .fullDay }
        if amOnly >= pmOnly { return .amOnly }
        return .pmOnly
    }

    var best: Int { max(fullDay, max(amOnly, pmOnly)) }
}

/// The full outcome of a decision, carrying the scores and flags the UI needs.
struct DecisionResult: Equatable {
    let recommendation: Recommendation
    let reason: DecisionReason
    let score: DayScore
    let bestOption: AttendanceOption
    let bestScore: Int
    let threshold: Int
    let slackWarning: Bool          // slack < 0
    let halfDaySurfaced: Bool       // a half-day beats fullDay by the margin
    let usedFutureComparison: Bool  // E7 ranking influenced the outcome path
}
