//
//  SettingsView.swift
//  officast
//
//  Edit onboarding values, this month's O, and reset the month (SPEC §6.4).
//

import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(\.modelContext) private var context
    @Query private var months: [MonthRecord]

    @State private var showingResetConfirm = false

    var body: some View {
        @Bindable var settings = settings
        NavigationStack {
            Form {
                Section("settings.locations") {
                    LocationPickerField(title: "onboarding.home", name: $settings.homeName) { _, lat, lng in
                        settings.homeLat = lat; settings.homeLng = lng
                    }
                    Toggle("onboarding.useOffice", isOn: $settings.hasOfficeLocation)
                    if settings.hasOfficeLocation {
                        LocationPickerField(title: "onboarding.office", name: $settings.officeName) { _, lat, lng in
                            settings.officeLat = lat; settings.officeLng = lng
                        }
                    }
                }

                Section("onboarding.timesSection") {
                    hourPicker("onboarding.departure", selection: $settings.departureHour)
                    hourPicker("onboarding.return", selection: $settings.returnHour)
                    hourPicker("onboarding.notify", selection: $settings.notifyHour)
                        .onChange(of: settings.notifyHour) { _, newValue in
                            NotificationScheduler.scheduleDaily(hour: newValue)
                        }
                }

                Section("onboarding.offDaysSection") {
                    WeekdaySelector(offDays: $settings.weeklyOffDays)
                }

                if let month = currentMonth {
                    Section("settings.thisMonth") {
                        Stepper(value: Binding(
                            get: { month.requiredOfficeDays },
                            set: { month.requiredOfficeDays = $0; try? context.save() }
                        ), in: 0...31) {
                            LabeledContent("onboarding.required", value: "\(month.requiredOfficeDays)")
                        }
                        .accessibilityIdentifier("settings.requiredDays")
                        Button("settings.resetMonth", role: .destructive) {
                            showingResetConfirm = true
                        }
                        .accessibilityIdentifier("settings.reset")
                    }
                }

                Section("settings.about") {
                    Link("settings.weatherCredit", destination: URL(string: "https://open-meteo.com/")!)
                        .accessibilityIdentifier("settings.weatherCredit")
                }
            }
            .navigationTitle("settings.title")
            .confirmationDialog("settings.resetConfirm", isPresented: $showingResetConfirm, titleVisibility: .visible) {
                Button("settings.resetMonth", role: .destructive) { resetMonth() }
                    .accessibilityIdentifier("settings.reset.confirm")
                Button("common.cancel", role: .cancel) {}
            }
        }
    }

    private func hourPicker(_ title: LocalizedStringKey, selection: Binding<Int>) -> some View {
        Picker(title, selection: selection) {
            ForEach(0..<24, id: \.self) { hour in
                Text(String(format: "%02d:00", hour)).tag(hour)
            }
        }
    }

    private var currentMonth: MonthRecord? {
        let key = DateKeys.monthKey(Date())
        return months.first { $0.yearMonth == key }
    }

    private func resetMonth() {
        guard let month = currentMonth else { return }
        for day in month.days { context.delete(day) }
        month.days.removeAll()
        month.priorOfficeCount = 0
        try? context.save()
    }
}
