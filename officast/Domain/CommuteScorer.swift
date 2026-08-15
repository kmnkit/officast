//
//  CommuteScorer.swift
//  officast
//
//  Rule-based commute-leg scoring (SPEC §3). Pure, no AI.
//  Start from 100, subtract penalties, clamp to [0, 100]. Higher = better commute.
//

import Foundation

enum CommuteScorer {

    /// Score a single commute leg from its nearest hourly forecast.
    static func score(_ hour: WeatherHour) -> Int {
        var score = 100

        // Rain: use the LARGER of the probability-based and intensity-based
        // penalties so we don't double-count (SPEC §3).
        score -= max(precipitationProbabilityPenalty(hour.popPct),
                     precipitationIntensityPenalty(hour.mmPerH))

        if hour.snow { score -= 50 }

        score -= windPenalty(hour.windMs)
        score -= temperaturePenalty(hour.tempC)

        return min(100, max(0, score))
    }

    // MARK: - Penalty tables (SPEC §3)

    private static func precipitationProbabilityPenalty(_ popPct: Int) -> Int {
        switch popPct {
        case 80...: return 40
        case 60..<80: return 25
        case 40..<60: return 12
        default: return 0
        }
    }

    private static func precipitationIntensityPenalty(_ mmPerH: Double) -> Int {
        if mmPerH >= 4 { return 45 }        // heavy
        if mmPerH > 0 { return 15 }         // light rain
        return 0
    }

    private static func windPenalty(_ windMs: Double) -> Int {
        if windMs >= 10 { return 20 }
        if windMs >= 7 { return 10 }
        return 0
    }

    private static func temperaturePenalty(_ tempC: Double) -> Int {
        if tempC >= 33 { return 15 }
        if tempC <= 2 { return 12 }
        return 0
    }
}
