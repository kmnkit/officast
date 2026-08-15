//
//  CommuteForecastTests.swift
//  officastTests
//
//  Leg lookup + interpolation (D4) and day-score composition.
//

import Foundation
import Testing
@testable import officast

struct CommuteForecastTests {

    private func hour(_ h: Int, pop: Int = 0) -> WeatherHour {
        WeatherHour(hour: h, popPct: pop, mmPerH: 0, snow: false, windMs: 3, tempC: 20)
    }

    @Test func exactHourIsNotInterpolated() {
        let r = CommuteForecast.legScore(hours: [hour(8, pop: 80)], targetHour: 8)
        #expect(r.score == 60)      // pop 80 → −40
        #expect(!r.interpolated)
    }

    @Test func interpolatesBetweenNeighbours() {
        // 7:00 clear (100), 9:00 heavy prob (60). Target 8 → average 80, interpolated.
        let r = CommuteForecast.legScore(hours: [hour(7), hour(9, pop: 80)], targetHour: 8)
        #expect(r.score == 80)
        #expect(r.interpolated)
    }

    @Test func usesOneSidedNeighbour() {
        let r = CommuteForecast.legScore(hours: [hour(6, pop: 80)], targetHour: 8)
        #expect(r.score == 60)
        #expect(r.interpolated)
    }

    @Test func neutralWhenNoData() {
        let r = CommuteForecast.legScore(hours: [], targetHour: 8)
        #expect(r.score == CommuteForecast.neutralScore)
        #expect(r.interpolated)
    }

    @Test func dayScoreUsesOfficeForEveningLeg() {
        // Home clear all day; office rains at 19:00 → evening leg penalized.
        let home = [hour(8), hour(12), hour(19)]
        let office = [hour(19, pop: 80)]
        let r = CommuteForecast.dayScore(home: home, office: office, departureHour: 8, returnHour: 19)
        #expect(r.score.fullDay == 60)   // min(morning 100, evening 60)
        #expect(r.score.amOnly == 100)   // min(morning 100, midday 100)
    }

    @Test func futureBestScoresSkipsDaysWithoutData() {
        let day = { (m: Int, d: Int) -> Date in
            var c = DateComponents(); c.year = 2026; c.month = m; c.day = d
            return Calendar(identifier: .gregorian).date(from: c)!
        }
        let d1 = day(8, 20), d2 = day(8, 21)
        let scores = CommuteForecast.futureBestScores(
            workdays: [d1, d2],
            homeByDate: [d1: [hour(8), hour(12), hour(19)]],   // d2 missing
            officeByDate: [:],
            departureHour: 8, returnHour: 19)
        #expect(scores == [100])
    }
}
