//
//  OnboardingView.swift
//  officast
//
//  First-run setup (SPEC §6.1): home + office location, commute/notify times,
//  this month's O, and any office days already attended this month (C13).
//

import SwiftUI
import SwiftData

struct OnboardingView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(\.modelContext) private var context

    @State private var homeName = ""
    @State private var homeLat = 0.0
    @State private var homeLng = 0.0

    @State private var useOffice = false
    @State private var officeName = ""
    @State private var officeLat = 0.0
    @State private var officeLng = 0.0

    @State private var departureHour = 8
    @State private var returnHour = 19
    @State private var notifyHour = 21
    @State private var weeklyOffDays: Set<Int> = [6, 7]

    @State private var requiredOfficeDays = 12
    @State private var priorOfficeCount = 0

    private var canSave: Bool { !homeName.isEmpty }

    var body: some View {
        NavigationStack {
            Form {
                Section("onboarding.homeSection") {
                    LocationPickerField(title: "onboarding.home", name: $homeName) { _, lat, lng in
                        homeLat = lat; homeLng = lng
                    }
                }

                Section("onboarding.officeSection") {
                    Toggle("onboarding.useOffice", isOn: $useOffice)
                    if useOffice {
                        LocationPickerField(title: "onboarding.office", name: $officeName) { _, lat, lng in
                            officeLat = lat; officeLng = lng
                        }
                    }
                }

                Section("onboarding.timesSection") {
                    hourPicker("onboarding.departure", selection: $departureHour)
                    hourPicker("onboarding.return", selection: $returnHour)
                    hourPicker("onboarding.notify", selection: $notifyHour)
                }

                Section("onboarding.offDaysSection") {
                    WeekdaySelector(offDays: $weeklyOffDays)
                }

                Section("onboarding.quotaSection") {
                    Stepper(value: $requiredOfficeDays, in: 0...31) {
                        LabeledContent("onboarding.required", value: "\(requiredOfficeDays)")
                    }
                    Stepper(value: $priorOfficeCount, in: 0...requiredOfficeDays) {
                        LabeledContent("onboarding.prior", value: "\(priorOfficeCount)")
                    }
                }
            }
            .navigationTitle("onboarding.title")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("onboarding.save") { save() }
                        .disabled(!canSave)
                }
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

    private func save() {
        settings.homeName = homeName
        settings.homeLat = homeLat
        settings.homeLng = homeLng
        settings.hasOfficeLocation = useOffice
        settings.officeName = officeName
        settings.officeLat = officeLat
        settings.officeLng = officeLng
        settings.departureHour = departureHour
        settings.returnHour = returnHour
        settings.notifyHour = notifyHour
        settings.weeklyOffDays = weeklyOffDays

        let monthKey = DateKeys.monthKey(Date())
        let record = MonthRepository.upsert(
            monthKey: monthKey, requiredOfficeDays: requiredOfficeDays, context: context)
        record.priorOfficeCount = priorOfficeCount
        try? context.save()

        settings.hasCompletedOnboarding = true

        Task {
            if await NotificationScheduler.requestAuthorization() {
                NotificationScheduler.registerCategory()
                NotificationScheduler.scheduleDaily(hour: notifyHour)
            }
        }
    }
}
