//
//  AppClock.swift
//  officast
//
//  Single source for "now". In production it's the system clock; under UI test
//  it can be pinned via `UITEST_TODAY` so date-sensitive recommendation logic
//  (remaining-workday count → decision threshold) is deterministic regardless of
//  when the suite runs — including the month's last workday.
//

import Foundation

enum AppClock {
    static var now: Date { UITestConfig.fixedToday ?? Date() }
}
