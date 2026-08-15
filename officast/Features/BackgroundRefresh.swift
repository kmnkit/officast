//
//  BackgroundRefresh.swift
//  officast
//
//  Best-effort evening forecast refresh via BGTaskScheduler (P2, Codex C4).
//  iOS decides whether and when this runs — the evening notification and the
//  offline cache are the primary defenses; this only freshens them opportunistically.
//

import Foundation
import BackgroundTasks
import SwiftData

enum BackgroundRefresh {

    static let taskIdentifier = "com.hobbylabo.officast.eveningRefresh"

    /// Register the handler. Must run before the app finishes launching.
    static func register(container: ModelContainer, settings: AppSettings) {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: taskIdentifier, using: nil) { task in
            guard let refreshTask = task as? BGAppRefreshTask else {
                task.setTaskCompleted(success: false)
                return
            }
            handle(refreshTask, container: container, settings: settings)
        }
    }

    /// Ask iOS to run the refresh after the next early-evening boundary.
    static func schedule(now: Date = Date(), calendar: Calendar = .current) {
        let request = BGAppRefreshTaskRequest(identifier: taskIdentifier)
        request.earliestBeginDate = nextEvening(now: now, calendar: calendar)
        try? BGTaskScheduler.shared.submit(request)
    }

    private static func nextEvening(now: Date, calendar: Calendar) -> Date {
        var components = DateComponents()
        components.hour = 20
        components.minute = 0
        return calendar.nextDate(after: now, matching: components, matchingPolicy: .nextTime)
            ?? now.addingTimeInterval(3600)
    }

    private static func handle(_ task: BGAppRefreshTask, container: ModelContainer, settings: AppSettings) {
        schedule()   // always line up the next one

        let work = Task { @MainActor in
            await DashboardModel.refreshTodayCache(settings: settings, container: container)
            task.setTaskCompleted(success: true)
        }
        task.expirationHandler = { work.cancel() }
    }
}
