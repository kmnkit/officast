//
//  MonthlyReport.swift
//  officast
//
//  Monthly summary (P4). Pure aggregation over the month's logged days and their
//  check-in weather snapshots — no UI, no persistence. The signature metric is
//  "rough-commute days you WFH'd": days you worked from home when the forecast
//  commute score was poor.
//

import Foundation

struct MonthlyReport: Equatable {
    /// Office days done this month (office logs + onboarding seed).
    let officeDone: Int
    /// Required office days this month (quota O).
    let requiredOfficeDays: Int
    /// Days logged as work-from-home this month.
    let wfhCount: Int
    /// WFH days whose check-in commute score was below `roughCommuteThreshold`
    /// (a rough forecast you avoided). Days without a snapshot don't count.
    let roughDaysAvoided: Int

    /// Below this commute score a day counts as a rough commute. At 70 the score
    /// table flags 80%+ rain (60), heavy rain ≥4mm (55), and snow (50), while
    /// leaving 60% rain (75) out. Higher score = better commute (CommuteScorer).
    static let roughCommuteThreshold = 70

    /// Aggregate a month's day records. `days` carries each logged day's status
    /// and its check-in snapshot (nil when no forecast was cached); `priorOffice`
    /// is the onboarding office seed (MonthRecord.priorOfficeCount).
    static func from(
        days: [(status: AttendanceStatus, snapshot: Int?)],
        requiredOfficeDays: Int,
        priorOffice: Int
    ) -> MonthlyReport {
        let officeLogged = days.filter { $0.status.countsAsOffice }.count
        let wfhDays = days.filter { $0.status == .wfh }
        let rough = wfhDays.filter { day in
            guard let score = day.snapshot else { return false }
            return score < roughCommuteThreshold
        }.count

        return MonthlyReport(
            officeDone: officeLogged + priorOffice,
            requiredOfficeDays: requiredOfficeDays,
            wfhCount: wfhDays.count,
            roughDaysAvoided: rough
        )
    }
}
