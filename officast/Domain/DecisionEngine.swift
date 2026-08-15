//
//  DecisionEngine.swift
//  officast
//
//  The crown jewel (SPEC §4). Pure decision logic:
//  option scores → threshold filter → E7 future-forecast bidirectional refinement.
//

import Foundation

enum DecisionEngine {

    /// A half-day must beat fullDay by at least this margin to be surfaced (SPEC Q3).
    static let halfDayMargin = 15

    /// E7: future comparison needs at least this many future workdays to be trusted.
    static let futureMinDays = 3

    /// E7: forecasts beyond this horizon are too inaccurate to use.
    static let futureMaxDays = 7

    // MARK: - Option scores (SPEC §4.1)

    /// Each option is the minimum of its two legs — the worse leg dictates the day.
    static func optionScores(morningOut: Int, midday: Int, eveningHome: Int) -> DayScore {
        DayScore(
            fullDay: min(morningOut, eveningHome),
            amOnly: min(morningOut, midday),
            pmOnly: min(midday, eveningHome)
        )
    }

    // MARK: - Recommendation

    /// Recommend attendance for today.
    ///
    /// - Parameters:
    ///   - today: today's option scores.
    ///   - month: quota arithmetic (provides slack and threshold).
    ///   - futureBestScores: best score for each of the *other* remaining workdays,
    ///     nearest first. Only the first `futureMaxDays` are considered (E7).
    static func recommend(
        today: DayScore,
        month: MonthMath,
        futureBestScores: [Int] = []
    ) -> DecisionResult {
        let bestOption = today.bestOption
        let bestScore = today.best
        let threshold = month.threshold
        let halfDaySurfaced = isHalfDaySurfaced(today)

        // 1. slack <= 0 → office every remaining day (SPEC §4.3). No future comparison.
        if month.slack <= 0 {
            return DecisionResult(
                recommendation: .office(bestOption),
                reason: month.slack < 0 ? .slackNegative : .slackZero,
                score: today,
                bestOption: bestOption,
                bestScore: bestScore,
                threshold: threshold,
                slackWarning: month.slack < 0,
                halfDaySurfaced: halfDaySurfaced,
                usedFutureComparison: false
            )
        }

        // 2. Threshold filter (SPEC §4.3): spend an office day on a good day.
        let baseIsOffice = bestScore >= threshold

        // 3. E7 refinement — only with enough future data (slack > 0 guaranteed here).
        let window = Array(futureBestScores.prefix(futureMaxDays))
        if window.count >= futureMinDays {
            // Is today among the best `oRemain` days left (today + future window)?
            let betterDaysAhead = window.filter { $0 > bestScore }.count
            let todayRank = betterDaysAhead + 1          // 1 = best day left
            let withinTopOffice = todayRank <= month.oRemain

            if baseIsOffice && !withinTopOffice {
                // Threshold said office, but enough better days are coming — save it.
                return result(.wfh, .futureBetterDaysAhead, today, bestOption, bestScore,
                              threshold, halfDaySurfaced, usedFuture: true)
            }
            if !baseIsOffice && withinTopOffice {
                // Threshold said WFH, but today is among the best left — don't miss it.
                return result(.office(bestOption), .futureTodayIsBest, today, bestOption, bestScore,
                              threshold, halfDaySurfaced, usedFuture: true)
            }
            // Ranking agrees with the threshold — keep the base decision.
            return result(baseIsOffice ? .office(bestOption) : .wfh,
                          baseIsOffice ? .goodDaySpend : .saveForWorse,
                          today, bestOption, bestScore, threshold, halfDaySurfaced,
                          usedFuture: true)
        }

        // 4. Not enough future data — threshold only (plan: "예보 부족 — 기본 추천").
        return result(baseIsOffice ? .office(bestOption) : .wfh,
                      baseIsOffice ? .goodDaySpend : .saveForWorse,
                      today, bestOption, bestScore, threshold, halfDaySurfaced,
                      usedFuture: false)
    }

    // MARK: - Helpers

    /// A half-day is surfaced when the better half beats fullDay by the margin.
    private static func isHalfDaySurfaced(_ score: DayScore) -> Bool {
        let bestHalf = max(score.amOnly, score.pmOnly)
        return bestHalf - score.fullDay >= halfDayMargin
    }

    private static func result(
        _ recommendation: Recommendation,
        _ reason: DecisionReason,
        _ score: DayScore,
        _ bestOption: AttendanceOption,
        _ bestScore: Int,
        _ threshold: Int,
        _ halfDaySurfaced: Bool,
        usedFuture: Bool
    ) -> DecisionResult {
        DecisionResult(
            recommendation: recommendation,
            reason: reason,
            score: score,
            bestOption: bestOption,
            bestScore: bestScore,
            threshold: threshold,
            slackWarning: false,
            halfDaySurfaced: halfDaySurfaced,
            usedFutureComparison: usedFuture
        )
    }
}
