//
//  CommuteForecast.swift
//  officast
//
//  Pure composition tying the weather cache to the scoring/decision engines:
//  nearest-hour leg lookup with interpolation fallback (D4), day scores, and
//  the future best-score list the E7 comparison consumes.
//

import Foundation

enum CommuteForecast {

    /// Neutral score used when a leg has no forecast at all (D4).
    static let neutralScore = 50

    /// Default hour for the midday changeover leg (~noon).
    static let middayHour = 12

    /// Score one leg from the day's hourly forecast. Uses the exact hour when
    /// present, else interpolates from the nearest neighbours (D4). The Bool is
    /// true when interpolation or the neutral fallback was used.
    static func legScore(hours: [WeatherHour], targetHour: Int) -> (score: Int, interpolated: Bool) {
        if let exact = hours.first(where: { $0.hour == targetHour }) {
            return (CommuteScorer.score(exact), false)
        }
        let before = hours.filter { $0.hour < targetHour }.max { $0.hour < $1.hour }
        let after = hours.filter { $0.hour > targetHour }.min { $0.hour < $1.hour }

        switch (before, after) {
        case let (b?, a?):
            return ((CommuteScorer.score(b) + CommuteScorer.score(a)) / 2, true)
        case let (b?, nil):
            return (CommuteScorer.score(b), true)
        case let (nil, a?):
            return (CommuteScorer.score(a), true)
        case (nil, nil):
            return (neutralScore, true)
        }
    }

    /// Build the three-option day score. Morning/midday legs use the home
    /// forecast; the evening leg uses the office forecast (E6).
    static func dayScore(
        home: [WeatherHour],
        office: [WeatherHour],
        departureHour: Int,
        returnHour: Int
    ) -> (score: DayScore, interpolated: Bool) {
        let morning = legScore(hours: home, targetHour: departureHour)
        let midday = legScore(hours: home, targetHour: middayHour)
        let evening = legScore(hours: office, targetHour: returnHour)
        let score = DecisionEngine.optionScores(
            morningOut: morning.score,
            midday: midday.score,
            eveningHome: evening.score
        )
        return (score, morning.interpolated || midday.interpolated || evening.interpolated)
    }

    /// Best score for each future workday that has forecast data, nearest first —
    /// the input to E7's relative ranking.
    static func futureBestScores(
        workdays: [Date],
        homeByDate: [Date: [WeatherHour]],
        officeByDate: [Date: [WeatherHour]],
        departureHour: Int,
        returnHour: Int
    ) -> [Int] {
        workdays.compactMap { day in
            guard let home = homeByDate[day], !home.isEmpty else { return nil }
            let office = officeByDate[day] ?? home
            return dayScore(home: home, office: office,
                            departureHour: departureHour, returnHour: returnHour).score.best
        }
    }
}
