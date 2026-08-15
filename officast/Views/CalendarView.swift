//
//  CalendarView.swift
//  officast
//
//  Month grid (SPEC §6.3): weekends greyed, tap a day to log or correct its
//  status. Holidays/vacation adjust R via the decision engine's offDays.
//

import SwiftUI
import SwiftData

struct CalendarView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(\.modelContext) private var context
    @Query private var months: [MonthRecord]

    @State private var selectedDate: Date?

    private let calendar = Calendar.current
    private let columns = Array(repeating: GridItem(.flexible()), count: 7)

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(weekdayHeaders, id: \.self) { header in
                        Text(header).font(.caption).foregroundStyle(.secondary)
                    }
                    ForEach(Array(gridDays.enumerated()), id: \.offset) { _, day in
                        if let day {
                            dayCell(day)
                        } else {
                            Color.clear.frame(height: 44)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle(Text(monthTitle))
            .confirmationDialog("calendar.setStatus", isPresented: statusDialogBinding, presenting: selectedDate) { date in
                ForEach(statusChoices, id: \.self) { status in
                    Button(RecommendationPresentation.statusLabel(status)) {
                        setStatus(status, for: date)
                    }
                }
                Button("calendar.clear", role: .destructive) { setStatus(.none, for: date) }
                Button("common.cancel", role: .cancel) {}
            }
        }
    }

    private func dayCell(_ date: Date) -> some View {
        let isWeekend = settings.weeklyOffDays.contains(WorkdayCalculator.isoWeekday(of: date, calendar: calendar))
        let status = status(for: date)
        let isToday = calendar.isDateInToday(date)
        let content = VStack(spacing: 2) {
            Text("\(calendar.component(.day, from: date))")
                .font(.callout)
                .foregroundStyle(isWeekend ? .secondary : .primary)
            Circle()
                .fill(color(for: status))
                .frame(width: 8, height: 8)
                .opacity(status == .none ? 0 : 1)
        }
        .frame(maxWidth: .infinity, minHeight: 44)
        return Button {
            selectedDate = date
        } label: {
            if isToday {
                // Today floats: glass replaces the flat fill so it reads as the
                // one focal cell without stacking glass on glass.
                content.glassEffect(.regular.interactive(), in: .rect(cornerRadius: 8))
            } else {
                content
                    .background(Color.secondary.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Data

    private var currentMonth: MonthRecord? {
        let key = DateKeys.monthKey(Date(), calendar: calendar)
        return months.first { $0.yearMonth == key }
    }

    private func status(for date: Date) -> AttendanceStatus {
        let day = calendar.startOfDay(for: date)
        return currentMonth?.days.first { calendar.startOfDay(for: $0.date) == day }?.status ?? .none
    }

    private func setStatus(_ status: AttendanceStatus, for date: Date) {
        let required = currentMonth?.requiredOfficeDays ?? 0
        let snapshot = WeatherSnapshot.score(for: date, settings: settings, context: context, calendar: calendar)
        MonthRepository.setStatus(date: date, status: status,
                                  requiredOfficeDays: required, weatherScoreSnapshot: snapshot,
                                  context: context, calendar: calendar)
    }

    private let statusChoices: [AttendanceStatus] =
        [.officeFull, .officeAM, .officePM, .wfh, .holiday, .vacation]

    private var statusDialogBinding: Binding<Bool> {
        Binding(get: { selectedDate != nil }, set: { if !$0 { selectedDate = nil } })
    }

    private func color(for status: AttendanceStatus) -> Color {
        switch status {
        case .officeFull, .officeAM, .officePM: return .green
        case .wfh: return .blue
        case .holiday, .vacation: return .orange
        case .none: return .clear
        }
    }

    // MARK: - Grid layout

    private var weekdayHeaders: [String] {
        let symbols = calendar.shortWeekdaySymbols
        let first = calendar.firstWeekday - 1
        return (0..<7).map { symbols[($0 + first) % 7] }
    }

    private var monthTitle: String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.dateFormat = "yyyy MMMM"
        return formatter.string(from: Date())
    }

    /// Days of the current month with leading nils to align the first weekday.
    private var gridDays: [Date?] {
        let today = Date()
        guard let interval = calendar.dateInterval(of: .month, for: today),
              let range = calendar.range(of: .day, in: .month, for: today) else { return [] }
        let firstWeekday = calendar.component(.weekday, from: interval.start)
        let leading = (firstWeekday - calendar.firstWeekday + 7) % 7
        var cells: [Date?] = Array(repeating: nil, count: leading)
        for day in range {
            var comps = calendar.dateComponents([.year, .month], from: today)
            comps.day = day
            cells.append(calendar.date(from: comps))
        }
        return cells
    }
}
