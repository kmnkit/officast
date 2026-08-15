//
//  RecommendationPresentation.swift
//  officast
//
//  Maps engine results to localized, user-facing text. Centralizes the l10n
//  keys so views stay declarative and translators have one place to look.
//

import Foundation

enum RecommendationPresentation {

    /// Short headline for a recommendation (e.g. "Office (afternoon only)").
    static func headline(_ result: DecisionResult) -> String {
        switch result.recommendation {
        case .office(let option): return optionLabel(option)
        case .wfh: return String(localized: "rec.wfh")
        }
    }

    static func optionLabel(_ option: AttendanceOption) -> String {
        switch option {
        case .fullDay: return String(localized: "rec.office.full")
        case .amOnly: return String(localized: "rec.office.am")
        case .pmOnly: return String(localized: "rec.office.pm")
        }
    }

    /// One-line reason for the recommendation.
    static func reason(_ result: DecisionResult) -> String {
        switch result.reason {
        case .slackNegative: return String(localized: "reason.slackNegative")
        case .slackZero: return String(localized: "reason.slackZero")
        case .goodDaySpend: return String(localized: "reason.goodDaySpend")
        case .saveForWorse: return String(localized: "reason.saveForWorse")
        case .futureBetterDaysAhead: return String(localized: "reason.futureBetterDaysAhead")
        case .futureTodayIsBest: return String(localized: "reason.futureTodayIsBest")
        }
    }

    /// Whether this recommendation is the app's signature half-day surfacing.
    static func isHalfDay(_ result: DecisionResult) -> Bool {
        if case .office(let option) = result.recommendation, option != .fullDay {
            return true
        }
        return false
    }

    /// Label for a logged status (calendar / history).
    static func statusLabel(_ status: AttendanceStatus) -> String {
        switch status {
        case .officeFull: return String(localized: "status.officeFull")
        case .officeAM: return String(localized: "status.officeAM")
        case .officePM: return String(localized: "status.officePM")
        case .wfh: return String(localized: "status.wfh")
        case .holiday: return String(localized: "status.holiday")
        case .vacation: return String(localized: "status.vacation")
        case .none: return String(localized: "status.none")
        }
    }
}
