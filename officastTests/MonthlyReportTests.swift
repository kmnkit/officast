//
//  MonthlyReportTests.swift
//  officastTests
//
//  Monthly summary aggregation (P4). Pure — no SwiftData.
//

import Foundation
import Testing
@testable import officast

struct MonthlyReportTests {

    typealias Day = (status: AttendanceStatus, snapshot: Int?)

    @Test func countsOfficeWithPriorSeed() {
        let days: [Day] = [
            (.officeFull, 90), (.officeAM, 88), (.wfh, 40),
        ]
        let r = MonthlyReport.from(days: days, requiredOfficeDays: 12, priorOffice: 3)
        #expect(r.officeDone == 5)          // 2 logged office + 3 seed
        #expect(r.requiredOfficeDays == 12)
        #expect(r.wfhCount == 1)
    }

    @Test func roughDaysAvoidedCountsWFHBelowThreshold() {
        let days: [Day] = [
            (.wfh, 69),   // below 70 → rough
            (.wfh, 55),   // rough
            (.wfh, 70),   // at threshold → not rough
            (.wfh, 90),   // clear → not rough
        ]
        let r = MonthlyReport.from(days: days, requiredOfficeDays: 10, priorOffice: 0)
        #expect(r.wfhCount == 4)
        #expect(r.roughDaysAvoided == 2)
    }

    @Test func missingSnapshotNeverCountsAsRough() {
        let days: [Day] = [
            (.wfh, nil),  // no forecast cached → not counted
            (.wfh, 30),   // rough
        ]
        let r = MonthlyReport.from(days: days, requiredOfficeDays: 10, priorOffice: 0)
        #expect(r.wfhCount == 2)
        #expect(r.roughDaysAvoided == 1)
    }

    @Test func officeAndOffDaysNeverCountAsRoughWFH() {
        // A low-score office/holiday day must not be miscounted as an avoided commute.
        let days: [Day] = [
            (.officeFull, 20), (.officeAM, 30), (.holiday, 10), (.vacation, nil),
        ]
        let r = MonthlyReport.from(days: days, requiredOfficeDays: 10, priorOffice: 0)
        #expect(r.wfhCount == 0)
        #expect(r.roughDaysAvoided == 0)
        #expect(r.officeDone == 2)
    }

    @Test func emptyMonthIsAllZeros() {
        let r = MonthlyReport.from(days: [], requiredOfficeDays: 8, priorOffice: 0)
        #expect(r == MonthlyReport(officeDone: 0, requiredOfficeDays: 8, wfhCount: 0, roughDaysAvoided: 0))
    }
}
