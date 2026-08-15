//
//  SettingsUITests.swift
//  officastUITests
//
//  Core flow: edit this month's required office days, then reset the month.
//  Changes are verified through the live-updating Report tab.
//

import XCTest

final class SettingsUITests: UITestCase {

    @MainActor
    func testEditRequiredDaysThenResetMonth() {
        launch([
            "UITEST_WEATHER": "sunny",
            "UITEST_QUOTA": "explicit",
            "UITEST_REQUIRED_DAYS": "10",
            "UITEST_PRIOR_COUNT": "3",
        ])
        assertValue("dashboard.progress.officeDone", equals: "3 / 10")

        // Bump required days 10 → 11.
        openTab(.settings)
        let stepper = app.steppers["settings.requiredDays"]
        XCTAssertTrue(stepper.waitForExistence(timeout: 8))
        // Two buttons: decrement (0), increment (1). Labels are localized, so use index.
        stepper.buttons.element(boundBy: 1).tap()

        openTab(.report)
        assertValue("report.officeDone", equals: "3 / 11")

        // Reset the month: clears logged days + prior seed (office done → 0).
        openTab(.settings)
        waitFor("settings.reset").tap()
        waitFor("settings.reset.confirm").tap()

        openTab(.report)
        assertValue("report.officeDone", equals: "0 / 11")
    }
}
