//
//  OnboardingUITests.swift
//  officastUITests
//
//  Core flow: the onboarding gate (ContentView routes on
//  AppSettings.hasCompletedOnboarding). Verified at both launch states — the
//  in-session Save→tabs transition is intentionally not asserted here because
//  AppSettings exposes UserDefaults-backed *computed* properties, which the
//  @Observable macro does not track, so the switch isn't reactive mid-session.
//

import XCTest

final class OnboardingUITests: UITestCase {

    @MainActor
    func testGateClosedShowsOnboarding() {
        launch(["UITEST_ONBOARDED": "0"])
        // The onboarding Save button is present; the main tabs are not.
        XCTAssertTrue(app.buttons["onboarding.save"].waitForExistence(timeout: 12),
                      "Onboarding should be shown when not yet completed")
        XCTAssertFalse(app.tabBars.buttons.element(boundBy: 0).exists,
                       "Tabs should be hidden during onboarding")
    }

    @MainActor
    func testGateOpenShowsTabs() {
        launch(["UITEST_ONBOARDED": "1", "UITEST_WEATHER": "sunny"])
        // Onboarded: the tab bar is present and the recommendation renders.
        waitFor("dashboard.today.option.officeFull")
        XCTAssertTrue(app.tabBars.buttons.element(boundBy: 0).exists)
        XCTAssertFalse(app.buttons["onboarding.save"].exists)
    }
}
