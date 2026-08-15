//
//  CommuteScorerTests.swift
//  officastTests
//
//  Golden cases for the rule-based leg scorer (SPEC §3).
//

import Testing
@testable import officast

struct CommuteScorerTests {

    private func hour(
        popPct: Int = 0, mmPerH: Double = 0, snow: Bool = false,
        windMs: Double = 3, tempC: Double = 20
    ) -> WeatherHour {
        WeatherHour(hour: 8, popPct: popPct, mmPerH: mmPerH, snow: snow, windMs: windMs, tempC: tempC)
    }

    @Test func perfectDayScores100() {
        #expect(CommuteScorer.score(hour()) == 100)
    }

    @Test(arguments: [
        (80, 40), (95, 40),   // ≥80% → −40
        (60, 25), (70, 25),   // 60–80% → −25
        (40, 12), (59, 12),   // 40–60% → −12
        (39, 0),  (0, 0),     // <40% → none
    ])
    func precipitationProbabilityPenalty(pop: Int, penalty: Int) {
        #expect(CommuteScorer.score(hour(popPct: pop)) == 100 - penalty)
    }

    @Test(arguments: [
        (4.0, 45), (10.0, 45),  // ≥4 mm/h heavy → −45
        (0.5, 15), (3.9, 15),   // light rain → −15
        (0.0, 0),               // dry
    ])
    func precipitationIntensityPenalty(mm: Double, penalty: Int) {
        #expect(CommuteScorer.score(hour(mmPerH: mm)) == 100 - penalty)
    }

    @Test func rainUsesLargerPenaltyNotBoth() {
        // pop 80 (−40) and heavy intensity (−45): take the larger, −45 → 55.
        #expect(CommuteScorer.score(hour(popPct: 80, mmPerH: 5)) == 55)
    }

    @Test func snowSubtracts50() {
        #expect(CommuteScorer.score(hour(snow: true)) == 50)
    }

    @Test(arguments: [(10.0, 20), (12.0, 20), (7.0, 10), (9.9, 10), (6.9, 0)])
    func windPenalty(windMs: Double, penalty: Int) {
        #expect(CommuteScorer.score(hour(windMs: windMs)) == 100 - penalty)
    }

    @Test(arguments: [(33.0, 15), (40.0, 15), (2.0, 12), (-5.0, 12), (20.0, 0)])
    func temperaturePenalty(tempC: Double, penalty: Int) {
        #expect(CommuteScorer.score(hour(tempC: tempC)) == 100 - penalty)
    }

    @Test func clampsToZeroWhenStacked() {
        // snow −50, heavy rain −45, wind −20, heat −15 = −130 → clamped to 0.
        let bad = hour(popPct: 0, mmPerH: 5, snow: true, windMs: 12, tempC: 34)
        #expect(CommuteScorer.score(bad) == 0)
    }
}
