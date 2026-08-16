//
//  officastApp.swift
//  officast
//
//  Created by Ginger Marco on 2026/08/15.
//

import SwiftUI
import SwiftData
import UserNotifications

@main
struct officastApp: App {
    @State private var settings = AppSettings()
    private let notificationDelegate = AppNotificationDelegate()

    init() {
        UNUserNotificationCenter.current().delegate = notificationDelegate
        if UITestConfig.isActive {
            // Hermetic UI-test launch: no background scheduling; seed a known state
            // into the in-memory store instead.
            TestSeeder.seed(container: sharedModelContainer)
        } else {
            BackgroundRefresh.register(container: sharedModelContainer, settings: AppSettings())
        }
    }

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            MonthRecord.self,
            DayRecord.self,
            WeatherCache.self,
        ])
        let modelConfiguration = ModelConfiguration(
            schema: schema, isStoredInMemoryOnly: UITestConfig.isActive)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(settings)
        }
        .modelContainer(sharedModelContainer)
    }
}
