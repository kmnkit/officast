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
    /// Month offset from today: -1 = previous, 0 = current, 1 = next.
    @State private var monthOffset: Int = 0
    @State private var holidays = HolidayStore()
    /// Region holidays (start-of-day) for the focused month, painted red.
    @State private var holidayDates: Set<Date> = []

    private let calendar = Calendar.current
    private let columns = Array(repeating: GridItem(.flexible()), count: 7)

    /// The month currently shown, anchored on today plus `monthOffset`.
    private var focusedMonth: Date {
        calendar.date(byAdding: .month, value: monthOffset, to: Date()) ?? Date()
    }

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
            .contentShape(Rectangle())
            .gesture(monthSwipe)
            .task(id: monthOffset) {
                holidayDates = await holidays.load(month: focusedMonth, calendar: calendar)
            }
            .navigationTitle(Text(monthTitle))
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { changeMonth(by: -1) } label: {
                        Image(systemName: "chevron.left")
                    }
                    .disabled(monthOffset <= -1)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { changeMonth(by: 1) } label: {
                        Image(systemName: "chevron.right")
                    }
                    .disabled(monthOffset >= 1)
                }
            }
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

    // MARK: - Month navigation

    /// Horizontal swipe: drag left → next month, drag right → previous month.
    private var monthSwipe: some Gesture {
        DragGesture(minimumDistance: 50)
            .onEnded { value in
                guard abs(value.translation.width) > abs(value.translation.height) else { return }
                changeMonth(by: value.translation.width < 0 ? 1 : -1)
            }
    }

    /// Shift the focused month within the allowed -1…1 range.
    private func changeMonth(by delta: Int) {
        let next = monthOffset + delta
        guard (-1...1).contains(next) else { return }
        withAnimation { monthOffset = next }
    }

    /// Day-number color: holidays and Sundays are red, Saturdays blue, else primary.
    private func dayColor(for date: Date) -> Color {
        if holidayDates.contains(calendar.startOfDay(for: date)) { return .red }
        switch WorkdayCalculator.isoWeekday(of: date, calendar: calendar) {
        case 7: return .red   // Sunday
        case 6: return .blue  // Saturday
        default: return .primary
        }
    }

    private func dayCell(_ date: Date) -> some View {
        let status = status(for: date)
        let isToday = calendar.isDateInToday(date)
        let content = VStack(spacing: 2) {
            Text("\(calendar.component(.day, from: date))")
                .font(.callout)
                .foregroundStyle(dayColor(for: date))
            if status != .none {
                Text(RecommendationPresentation.statusLabel(status))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
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
        let key = DateKeys.monthKey(focusedMonth, calendar: calendar)
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
        AnalyticsLogger.logAttendanceStatus(status)
    }

    private let statusChoices: [AttendanceStatus] =
        [.officeFull, .officeAM, .officePM, .wfh, .holiday, .vacation]

    private var statusDialogBinding: Binding<Bool> {
        Binding(get: { selectedDate != nil }, set: { if !$0 { selectedDate = nil } })
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
        return formatter.string(from: focusedMonth)
    }

    /// Days of the current month with leading nils to align the first weekday.
    private var gridDays: [Date?] {
        let month = focusedMonth
        guard let interval = calendar.dateInterval(of: .month, for: month),
              let range = calendar.range(of: .day, in: .month, for: month) else { return [] }
        let firstWeekday = calendar.component(.weekday, from: interval.start)
        let leading = (firstWeekday - calendar.firstWeekday + 7) % 7
        var cells: [Date?] = Array(repeating: nil, count: leading)
        for day in range {
            var comps = calendar.dateComponents([.year, .month], from: month)
            comps.day = day
            cells.append(calendar.date(from: comps))
        }
        return cells
    }
}
