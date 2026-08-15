//
//  officastUITestsLaunchTests.swift
//  officastUITests
//
//  Created by Ginger Marco on 2026/08/15.
//

import XCTest

final class officastUITestsLaunchTests: XCTestCase {

    override class var runsForEachTargetApplicationUIConfiguration: Bool {
        true
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testLaunch() throws {
        let app = XCUIApplication()
        // Launch hermetically (seeded + stubbed weather) so the screenshot is
        // deterministic and doesn't depend on the live weather network.
        app.launchEnvironment = ["UITEST": "1", "UITEST_WEATHER": "sunny", "UITEST_TODAY": "2026-06-15"]
        app.launch()

        // Insert steps here to perform after app launch but before taking a screenshot,
        // such as logging into a test account or navigating somewhere in the app
        // XCUIAutomation Documentation
        // https://developer.apple.com/documentation/xcuiautomation

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Launch Screen"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
