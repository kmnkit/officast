//
//  AppSettingsTests.swift
//  officastTests
//
//  Settings round-trip and defaults, backed by an isolated UserDefaults suite.
//

import Foundation
import Testing
@testable import officast

struct AppSettingsTests {

    private func makeSettings() -> AppSettings {
        let suite = "test.officast.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return AppSettings(defaults: defaults)
    }

    @Test func defaultsMatchSpec() {
        let s = makeSettings()
        #expect(s.departureHour == 8)
        #expect(s.returnHour == 19)
        #expect(s.notifyHour == 21)
        #expect(s.weeklyOffDays == [6, 7])
        #expect(!s.hasCompletedOnboarding)
        #expect(!s.hasOfficeLocation)
    }

    @Test func roundTripsValues() {
        let s = makeSettings()
        s.homeLat = 35.5
        s.homeLng = 139.7
        s.homeName = "Tokyo"
        s.departureHour = 7
        s.weeklyOffDays = [7]
        s.hasCompletedOnboarding = true
        #expect(s.homeLat == 35.5)
        #expect(s.homeLng == 139.7)
        #expect(s.homeName == "Tokyo")
        #expect(s.departureHour == 7)
        #expect(s.weeklyOffDays == [7])
        #expect(s.hasCompletedOnboarding)
    }

    @Test func eveningLegFallsBackToHomeWithoutOffice() {
        let s = makeSettings()
        s.homeLat = 35.0
        s.homeLng = 139.0
        let coord = s.eveningLegCoordinate
        #expect(coord.lat == 35.0)
        #expect(coord.lng == 139.0)
    }

    @Test func eveningLegUsesOfficeWhenSet() {
        let s = makeSettings()
        s.homeLat = 35.0
        s.homeLng = 139.0
        s.hasOfficeLocation = true
        s.officeLat = 35.6
        s.officeLng = 139.8
        let coord = s.eveningLegCoordinate
        #expect(coord.lat == 35.6)
        #expect(coord.lng == 139.8)
    }
}
