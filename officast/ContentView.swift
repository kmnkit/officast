//
//  ContentView.swift
//  officast
//
//  Root gate: onboarding until set up, then the main tabs. Applies any pending
//  notification check-in when the app becomes active.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Group {
            if settings.hasCompletedOnboarding {
                TabView {
                    DashboardView()
                        .tabItem { Label("dashboard.title", systemImage: "cloud.sun") }
                    CalendarView()
                        .tabItem { Label("calendar.title", systemImage: "calendar") }
                    SettingsView()
                        .tabItem { Label("settings.title", systemImage: "gearshape") }
                }
            } else {
                OnboardingView()
            }
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active:
                MonthRepository.applyPendingCheckIn(settings: settings, context: context)
            case .background:
                BackgroundRefresh.schedule()
            default:
                break
            }
        }
    }
}

#Preview {
    ContentView()
        .environment(AppSettings())
        .modelContainer(for: [MonthRecord.self, DayRecord.self, WeatherCache.self], inMemory: true)
}
