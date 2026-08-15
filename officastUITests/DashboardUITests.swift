//
//  DashboardUITests.swift
//  officastUITests
//
//  Deterministic recommendation decisions (stubbed weather), progress display,
//  the slack-negative warning, and the offline / error paths.
//

import XCTest

final class DashboardUITests: UITestCase {

    /// Pin "today" to a mid-month weekday so the remaining-workday count (and thus
    /// the decision threshold) is stable regardless of when the suite runs —
    /// including the month's last workday.
    private let fixedToday = "2026-06-15"

    // MARK: - Recommendation (calibrated stub → fixed decision)

    @MainActor
    func testSunnyRecommendsOfficeFull() {
        launch(["UITEST_WEATHER": "sunny", "UITEST_TODAY": fixedToday])
        waitFor("dashboard.today.option.officeFull")
    }

    @MainActor
    func testRainyTodayRecommendsWFH() {
        launch(["UITEST_WEATHER": "rainy_today", "UITEST_TODAY": fixedToday])
        waitFor("dashboard.today.option.wfh")
    }

    @MainActor
    func testAmClearPmRainRecommendsOfficeMorning() {
        launch(["UITEST_WEATHER": "am_clear_pm_rain", "UITEST_TODAY": fixedToday])
        waitFor("dashboard.today.option.officeAM")
    }

    // MARK: - Progress + slack

    @MainActor
    func testProgressReflectsSeededQuota() {
        launch([
            "UITEST_WEATHER": "sunny",
            "UITEST_QUOTA": "explicit",
            "UITEST_REQUIRED_DAYS": "10",
            "UITEST_PRIOR_COUNT": "3",
        ])
        assertValue("dashboard.progress.officeDone", equals: "3 / 10")
    }

    @MainActor
    func testSlackNegativeShowsWarning() {
        launch(["UITEST_WEATHER": "sunny", "UITEST_QUOTA": "slackNegative"])
        waitFor("dashboard.slackWarning")
    }

    // MARK: - Offline / error

    @MainActor
    func testWeatherFailureShowsRetry() {
        launch(["UITEST_WEATHER": "fetch_fail"])
        waitFor("dashboard.retry")
    }

    @MainActor
    func testOfflineBannerFromCache() {
        launch(["UITEST_WEATHER": "fetch_fail_cached", "UITEST_TODAY": fixedToday])
        waitFor("dashboard.offlineBanner")
        // A recommendation still renders from the cached forecast.
        waitFor("dashboard.today.option.officeFull")
    }
}
