//
//  ReportUITests.swift
//  officastUITests
//
//  Core flow: the monthly report aggregates seeded day records, including the
//  signature "rough-commute days you WFH'd" metric (snapshot < 70).
//

import XCTest

final class ReportUITests: UITestCase {

    @MainActor
    func testReportAggregatesSeededMonth() {
        // 2 office, 3 WFH; WFH snapshots 20 & 40 are rough (< 70), 90 is not.
        launch([
            "UITEST_WEATHER": "sunny",
            "UITEST_QUOTA": "explicit",
            "UITEST_REQUIRED_DAYS": "12",
            "UITEST_PRIOR_COUNT": "0",
            "UITEST_SEED_DAYS": "office_full:80,office_full:70,wfh:20,wfh:90,wfh:40",
        ])
        openTab(.report)
        assertValue("report.officeDone", equals: "2 / 12")
        assertValue("report.wfhCount", equals: "3")
        assertValue("report.roughDaysAvoided", equals: "2")
    }
}
