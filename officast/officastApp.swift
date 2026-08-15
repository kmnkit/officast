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
    }

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            MonthRecord.self,
            DayRecord.self,
            WeatherCache.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

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
