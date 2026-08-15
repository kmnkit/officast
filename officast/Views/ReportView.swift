//
//  ReportView.swift
//  officast
//
//  Monthly summary (P4): this month's office progress, WFH count, and the
//  signature "rough-commute days you WFH'd" metric derived from check-in
//  weather snapshots. Current month only, matching CalendarView.
//

import SwiftUI
import SwiftData

struct ReportView: View {
    @Environment(\.modelContext) private var context
    @Query private var months: [MonthRecord]

    private let calendar = Calendar.current

    var body: some View {
        NavigationStack {
            List {
                Section("report.progress") {
                    LabeledContent("report.officeDone",
                                   value: "\(report.officeDone) / \(report.requiredOfficeDays)")
                    LabeledContent("report.wfhCount", value: "\(report.wfhCount)")
                }

                Section("report.insight") {
                    Label {
                        Text("report.roughDaysAvoided \(report.roughDaysAvoided)")
                    } icon: {
                        Image(systemName: "house.fill").foregroundStyle(.blue)
                    }
                    Text("report.roughDaysNote")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle(Text(monthTitle))
        }
    }

    private var currentMonth: MonthRecord? {
        let key = DateKeys.monthKey(Date(), calendar: calendar)
        return months.first { $0.yearMonth == key }
    }

    private var report: MonthlyReport {
        guard let month = currentMonth else {
            return MonthlyReport(officeDone: 0, requiredOfficeDays: 0, wfhCount: 0, roughDaysAvoided: 0)
        }
        let days = month.days.map { (status: $0.status, snapshot: $0.weatherScoreSnapshot) }
        return MonthlyReport.from(
            days: days,
            requiredOfficeDays: month.requiredOfficeDays,
            priorOffice: month.priorOfficeCount)
    }

    private var monthTitle: String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.dateFormat = "yyyy MMMM"
        return formatter.string(from: Date())
    }
}
