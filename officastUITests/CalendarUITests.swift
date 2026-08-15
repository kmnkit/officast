//
//  CalendarUITests.swift
//  officastUITests
//
//  Core flow: tap a day, log an office status, and verify it persisted (read
//  back through the live-updating Report tab).
//

import XCTest

final class CalendarUITests: UITestCase {

    @MainActor
    func testLogOfficeDayPersists() {
        launch([
            "UITEST_WEATHER": "sunny",
            "UITEST_QUOTA": "explicit",
            "UITEST_REQUIRED_DAYS": "10",
            "UITEST_PRIOR_COUNT": "0",
        ])
        // Baseline: nothing logged yet.
        assertValue("dashboard.progress.officeDone", equals: "0 / 10")

        openTab(.calendar)
        waitFor(dayIdentifier()).tap()          // today's cell → status dialog
        waitFor("calendar.status.office").tap()  // log a full office day

        // Report reads SwiftData live, so the office count reflects the new log.
        openTab(.report)
        assertValue("report.officeDone", equals: "1 / 10")
    }
}
