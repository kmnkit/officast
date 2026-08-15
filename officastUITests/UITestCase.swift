//
//  UITestCase.swift
//  officastUITests
//
//  Shared base for the hermetic UI suite: launches the app with `UITEST=1`
//  plus a per-test environment (weather scenario, quota, seeded state), and
//  provides identifier-based element helpers. All app-side hooks live behind
//  the UITEST flag (see officast/TestSupport).
//

import XCTest

class UITestCase: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    /// Launch in hermetic UI-test mode with the given launch environment.
    @discardableResult
    func launch(_ env: [String: String] = [:]) -> XCUIApplication {
        var environment = env
        environment["UITEST"] = "1"
        app.launchEnvironment = environment
        app.launch()
        return app
    }

    // MARK: - Elements (query by identifier, any element type)

    func element(_ identifier: String) -> XCUIElement {
        // firstMatch: an accessibilityIdentifier on a control also tags its inner
        // label, yielding several matches — the first (the control) is what we want.
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    @discardableResult
    func waitFor(_ identifier: String, timeout: TimeInterval = 12) -> XCUIElement {
        let el = element(identifier)
        XCTAssertTrue(el.waitForExistence(timeout: timeout),
                      "Expected element '\(identifier)' to appear within \(timeout)s")
        return el
    }

    func assertValue(_ identifier: String, equals expected: String, timeout: TimeInterval = 12) {
        let el = waitFor(identifier, timeout: timeout)
        XCTAssertEqual(el.value as? String, expected,
                       "Element '\(identifier)' value mismatch")
    }

    // MARK: - Tabs (labels are localized → navigate by index)

    enum Tab: Int { case dashboard = 0, calendar = 1, report = 2, settings = 3 }

    func openTab(_ tab: Tab) {
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 12), "Tab bar not found")
        let button = app.tabBars.buttons.element(boundBy: tab.rawValue)
        XCTAssertTrue(button.waitForExistence(timeout: 8), "Tab \(tab) not found")
        button.tap()
    }

    /// Wait until the app is in the foreground (after activate()).
    func waitForForeground(timeout: TimeInterval = 12) {
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: timeout),
                      "App did not reach the foreground")
    }

    /// "calendar.day.<yyyy-MM-dd>" identifier for a date, matching CalendarView.
    func dayIdentifier(_ date: Date = Date(), calendar: Calendar = .current) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "calendar.day.%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }
}
