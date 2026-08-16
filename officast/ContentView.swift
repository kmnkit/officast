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

    // Deep-linked at launch for UI-test screenshots; defaults to the first tab
    // in production (UITestConfig.initialTabIndex is nil unless UITEST is set).
    @State private var selectedTab: Int = UITestConfig.initialTabIndex ?? 0

    var body: some View {
        Group {
            if settings.hasCompletedOnboarding {
                TabView(selection: $selectedTab) {
                    DashboardView()
                        .tabItem { Label("dashboard.title", systemImage: "cloud.sun") }
                        .tag(0)
                    CalendarView()
                        .tabItem { Label("calendar.title", systemImage: "calendar") }
                        .tag(1)
                    ReportView()
                        .tabItem { Label("report.title", systemImage: "chart.bar") }
                        .tag(2)
                    SettingsView()
                        .tabItem { Label("settings.title", systemImage: "gearshape") }
                        .tag(3)
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
