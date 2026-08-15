//
//  AppSettings.swift
//  officast
//
//  UserDefaults-backed settings (SPEC §7). Home + office coordinates, commute
//  times, notification time, and weekly days off. `O` lives on MonthRecord, not
//  here, because it is per-month.
//

import Foundation
import Observation

@Observable
final class AppSettings {

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    private enum Key {
        static let hasCompletedOnboarding = "hasCompletedOnboarding"
        static let homeLat = "homeLat"
        static let homeLng = "homeLng"
        static let homeName = "homeName"
        static let hasOfficeLocation = "hasOfficeLocation"
        static let officeLat = "officeLat"
        static let officeLng = "officeLng"
        static let officeName = "officeName"
        static let departureHour = "departureHour"
        static let returnHour = "returnHour"
        static let notifyHour = "notifyHour"
        static let weeklyOffDays = "weeklyOffDays"
    }

    var hasCompletedOnboarding: Bool {
        get { defaults.bool(forKey: Key.hasCompletedOnboarding) }
        set { defaults.set(newValue, forKey: Key.hasCompletedOnboarding) }
    }

    var homeLat: Double {
        get { defaults.double(forKey: Key.homeLat) }
        set { defaults.set(newValue, forKey: Key.homeLat) }
    }

    var homeLng: Double {
        get { defaults.double(forKey: Key.homeLng) }
        set { defaults.set(newValue, forKey: Key.homeLng) }
    }

    var homeName: String {
        get { defaults.string(forKey: Key.homeName) ?? "" }
        set { defaults.set(newValue, forKey: Key.homeName) }
    }

    /// Whether a distinct office location was entered. When false, the evening
    /// leg falls back to the home coordinates (E6).
    var hasOfficeLocation: Bool {
        get { defaults.bool(forKey: Key.hasOfficeLocation) }
        set { defaults.set(newValue, forKey: Key.hasOfficeLocation) }
    }

    var officeLat: Double {
        get { defaults.double(forKey: Key.officeLat) }
        set { defaults.set(newValue, forKey: Key.officeLat) }
    }

    var officeLng: Double {
        get { defaults.double(forKey: Key.officeLng) }
        set { defaults.set(newValue, forKey: Key.officeLng) }
    }

    var officeName: String {
        get { defaults.string(forKey: Key.officeName) ?? "" }
        set { defaults.set(newValue, forKey: Key.officeName) }
    }

    var departureHour: Int {
        get { defaults.object(forKey: Key.departureHour) as? Int ?? 8 }
        set { defaults.set(newValue, forKey: Key.departureHour) }
    }

    var returnHour: Int {
        get { defaults.object(forKey: Key.returnHour) as? Int ?? 19 }
        set { defaults.set(newValue, forKey: Key.returnHour) }
    }

    var notifyHour: Int {
        get { defaults.object(forKey: Key.notifyHour) as? Int ?? 21 }
        set { defaults.set(newValue, forKey: Key.notifyHour) }
    }

    /// ISO weekday numbers off every week (Mon=1 … Sun=7). Default Sat/Sun.
    var weeklyOffDays: Set<Int> {
        get {
            let stored = defaults.array(forKey: Key.weeklyOffDays) as? [Int]
            return Set(stored ?? [6, 7])
        }
        set { defaults.set(Array(newValue).sorted(), forKey: Key.weeklyOffDays) }
    }

    /// The coordinate to use for the evening (office → home) leg: office if set,
    /// otherwise home (E6 fallback).
    var eveningLegCoordinate: (lat: Double, lng: Double) {
        hasOfficeLocation ? (officeLat, officeLng) : (homeLat, homeLng)
    }
}
