//
//  DecisionEngineTests.swift
//  officastTests
//
//  Golden cases for the decision engine (SPEC §4) including the E7
//  bidirectional future-forecast refinement.
//

import Testing
@testable import officast

struct DecisionEngineTests {

    // MARK: - Option scores (SPEC §4.1)

    @Test func optionScoresAreMinOfLegs() {
        let s = DecisionEngine.optionScores(morningOut: 80, midday: 40, eveningHome: 90)
        #expect(s.fullDay == 80)   // min(80, 90)
        #expect(s.amOnly == 40)    // min(80, 40)
        #expect(s.pmOnly == 40)    // min(40, 90)
        #expect(s.best == 80)
        #expect(s.bestOption == .fullDay)
    }

    @Test func halfDaySurfacedWhenItBeatsFullByMargin() {
        // Rainy morning kills fullDay; a clear evening makes pmOnly shine.
        let s = DecisionEngine.optionScores(morningOut: 30, midday: 90, eveningHome: 95)
        let m = MonthMath(requiredOfficeDays: 10, officeDone: 0, remainingWorkdays: 20)
        let r = DecisionEngine.recommend(today: s, month: m)
        #expect(s.bestOption == .pmOnly)
        #expect(r.halfDaySurfaced)
    }

    // MARK: - slack branches (SPEC §4.3)

    @Test func slackZeroAlwaysOffice() {
        let s = DecisionEngine.optionScores(morningOut: 10, midday: 10, eveningHome: 10)
        let m = MonthMath(requiredOfficeDays: 10, officeDone: 0, remainingWorkdays: 10)
        let r = DecisionEngine.recommend(today: s, month: m)
        #expect(r.recommendation == .office(.fullDay))
        #expect(r.reason == .slackZero)
        #expect(!r.slackWarning)
    }

    @Test func slackNegativeWarnsAndOffices() {
        let s = DecisionEngine.optionScores(morningOut: 20, midday: 20, eveningHome: 20)
        let m = MonthMath(requiredOfficeDays: 12, officeDone: 2, remainingWorkdays: 5)
        let r = DecisionEngine.recommend(today: s, month: m)
        #expect(r.recommendation == .office(.fullDay))
        #expect(r.reason == .slackNegative)
        #expect(r.slackWarning)
    }

    // MARK: - Threshold only (no future data)

    @Test func goodDaySpendsOfficeWhenAboveThreshold() {
        // O=10 done=0 R=20 → ratio 0.5 → T=50. best 80 ≥ 50 → office.
        let s = DecisionEngine.optionScores(morningOut: 80, midday: 80, eveningHome: 80)
        let m = MonthMath(requiredOfficeDays: 10, officeDone: 0, remainingWorkdays: 20)
        let r = DecisionEngine.recommend(today: s, month: m)
        #expect(r.recommendation == .office(.fullDay))
        #expect(r.reason == .goodDaySpend)
        #expect(!r.usedFutureComparison)
    }

    @Test func savesForWorseWhenBelowThreshold() {
        // Same month (T=50). best 40 < 50 → WFH.
        let s = DecisionEngine.optionScores(morningOut: 40, midday: 40, eveningHome: 40)
        let m = MonthMath(requiredOfficeDays: 10, officeDone: 0, remainingWorkdays: 20)
        let r = DecisionEngine.recommend(today: s, month: m)
        #expect(r.recommendation == .wfh)
        #expect(r.reason == .saveForWorse)
    }

    // MARK: - E7 bidirectional refinement

    @Test func e7DowngradesWhenBetterDaysAhead() {
        // O=2 done=0 R=20 → oRemain 2, T=90. best 95 ≥ 90 → base office.
        // Three future days all better than 95 → today ranks 4 > oRemain 2 → WFH.
        let s = DecisionEngine.optionScores(morningOut: 95, midday: 95, eveningHome: 95)
        let m = MonthMath(requiredOfficeDays: 2, officeDone: 0, remainingWorkdays: 20)
        let r = DecisionEngine.recommend(today: s, month: m, futureBestScores: [96, 97, 98])
        #expect(r.recommendation == .wfh)
        #expect(r.reason == .futureBetterDaysAhead)
        #expect(r.usedFutureComparison)
    }

    @Test func e7UpgradesWhenTodayIsBestLeft() {
        // O=8 done=0 R=10 → oRemain 8, T=20. best 15 < 20 → base WFH.
        // All three future days worse → today ranks 1 ≤ 8 → office.
        let s = DecisionEngine.optionScores(morningOut: 15, midday: 15, eveningHome: 15)
        let m = MonthMath(requiredOfficeDays: 8, officeDone: 0, remainingWorkdays: 10)
        let r = DecisionEngine.recommend(today: s, month: m, futureBestScores: [10, 12, 8])
        #expect(r.recommendation == .office(.fullDay))
        #expect(r.reason == .futureTodayIsBest)
        #expect(r.usedFutureComparison)
    }

    @Test func e7KeepsBaseWhenRankingAgrees() {
        // O=10 done=0 R=20 → T=50. best 80 office, and today is best of the window → keep office.
        let s = DecisionEngine.optionScores(morningOut: 80, midday: 80, eveningHome: 80)
        let m = MonthMath(requiredOfficeDays: 10, officeDone: 0, remainingWorkdays: 20)
        let r = DecisionEngine.recommend(today: s, month: m, futureBestScores: [40, 30, 20])
        #expect(r.recommendation == .office(.fullDay))
        #expect(r.reason == .goodDaySpend)
        #expect(r.usedFutureComparison)
    }

    @Test func e7IgnoredWithTooFewFutureDays() {
        // Only two future days (< futureMinDays) → threshold only.
        let s = DecisionEngine.optionScores(morningOut: 95, midday: 95, eveningHome: 95)
        let m = MonthMath(requiredOfficeDays: 2, officeDone: 0, remainingWorkdays: 20)
        let r = DecisionEngine.recommend(today: s, month: m, futureBestScores: [96, 97])
        #expect(r.recommendation == .office(.fullDay))
        #expect(!r.usedFutureComparison)
    }
}
