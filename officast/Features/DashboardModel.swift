//
//  DashboardModel.swift
//  officast
//
//  Orchestration brain: fetch forecasts, compose today's and tomorrow's
//  recommendation, and fall back to the weather cache when offline. The pure
//  `build` step is separated from I/O; the scoring/decision math it calls is
//  the already-tested crown jewel.
//

import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class DashboardModel {

    struct Data {
        let today: DecisionResult
        let tomorrow: DecisionResult?
        let todayInterpolated: Bool
        let hasTodayForecast: Bool
        let officeDone: Int
        let requiredOfficeDays: Int
        let remainingWorkdays: Int
        let slack: Int
        let offline: Bool
    }

    enum State {
        case idle
        case loading
        case loaded(Data)
        case failed(String)
    }

    var state: State = .idle

    private let weather: WeatherFetching
    private let calendar: Calendar

    init(weather: WeatherFetching? = nil, calendar: Calendar = .current) {
        self.weather = weather ?? WeatherClientFactory.make()
        self.calendar = calendar
    }

    /// Forecast horizon: today + up to 7 future days for E7.
    private static let forecastDays = 8

    func refresh(settings: AppSettings, month: MonthRecord, context: ModelContext, now: Date = Date()) async {
        state = .loading
        let offDays = Self.offDays(in: month, calendar: calendar)
        let todayLogged = Self.isLogged(month: month, date: now, calendar: calendar)

        do {
            let homeByDate = try await weather.fetchDailyHourly(
                latitude: settings.homeLat, longitude: settings.homeLng, forecastDays: Self.forecastDays)
            let officeByDate: [Date: [WeatherHour]]
            if settings.hasOfficeLocation {
                officeByDate = try await weather.fetchDailyHourly(
                    latitude: settings.officeLat, longitude: settings.officeLng, forecastDays: Self.forecastDays)
            } else {
                officeByDate = homeByDate
            }

            Self.cacheToday(homeByDate: homeByDate, now: now, calendar: calendar, context: context)

            let data = Self.build(
                requiredOfficeDays: month.requiredOfficeDays,
                officeDone: month.officeDone,
                offDays: offDays,
                weeklyOffDays: settings.weeklyOffDays,
                homeByDate: homeByDate, officeByDate: officeByDate,
                departureHour: settings.departureHour, returnHour: settings.returnHour,
                today: now, todayLogged: todayLogged, offline: false, calendar: calendar)
            state = .loaded(data)
        } catch {
            // Offline: rebuild today from the cache if we have it (SPEC error registry).
            if let cached = Self.cachedToday(now: now, calendar: calendar, context: context) {
                let key = DateKeys.dayKey(now, calendar: calendar)
                let data = Self.build(
                    requiredOfficeDays: month.requiredOfficeDays,
                    officeDone: month.officeDone,
                    offDays: offDays,
                    weeklyOffDays: settings.weeklyOffDays,
                    homeByDate: [key: cached], officeByDate: [key: cached],
                    departureHour: settings.departureHour, returnHour: settings.returnHour,
                    today: now, todayLogged: todayLogged, offline: true, calendar: calendar)
                state = .loaded(data)
            } else {
                state = .failed(String(localized: "error.weatherUnavailable"))
            }
        }
    }

    // MARK: - Pure composition

    static func build(
        requiredOfficeDays: Int,
        officeDone: Int,
        offDays: Set<Date>,
        weeklyOffDays: Set<Int>,
        homeByDate: [Date: [WeatherHour]],
        officeByDate: [Date: [WeatherHour]],
        departureHour: Int,
        returnHour: Int,
        today: Date,
        todayLogged: Bool,
        offline: Bool,
        calendar: Calendar
    ) -> Data {
        let localToday = calendar.startOfDay(for: today)
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: localToday) ?? localToday

        // R: today counts before check-in; once logged, count from tomorrow (C6).
        let rFrom = todayLogged ? tomorrow : localToday
        let workdays = WorkdayCalculator.workdayDates(
            from: rFrom, weeklyOffDays: weeklyOffDays, offDays: offDays, calendar: calendar)
        let month = MonthMath(requiredOfficeDays: requiredOfficeDays,
                              officeDone: officeDone, remainingWorkdays: workdays.count)

        let todayKey = DateKeys.dayKey(localToday, calendar: calendar)
        let todayHome = homeByDate[todayKey] ?? []
        let todayOffice = officeByDate[todayKey] ?? todayHome
        let todayScore = CommuteForecast.dayScore(
            home: todayHome, office: todayOffice,
            departureHour: departureHour, returnHour: returnHour)

        let futureKeys = workdays.filter { $0 > localToday }.map { DateKeys.dayKey($0, calendar: calendar) }
        let futureScores = CommuteForecast.futureBestScores(
            workdays: futureKeys, homeByDate: homeByDate, officeByDate: officeByDate,
            departureHour: departureHour, returnHour: returnHour)

        let todayResult = DecisionEngine.recommend(
            today: todayScore.score, month: month, futureBestScores: futureScores)

        let tomorrowResult = buildTomorrow(
            requiredOfficeDays: requiredOfficeDays, officeDone: officeDone,
            offDays: offDays, weeklyOffDays: weeklyOffDays,
            homeByDate: homeByDate, officeByDate: officeByDate,
            departureHour: departureHour, returnHour: returnHour,
            tomorrow: tomorrow, calendar: calendar)

        return Data(
            today: todayResult, tomorrow: tomorrowResult,
            todayInterpolated: todayScore.interpolated, hasTodayForecast: !todayHome.isEmpty,
            officeDone: officeDone, requiredOfficeDays: requiredOfficeDays,
            remainingWorkdays: workdays.count, slack: month.slack, offline: offline)
    }

    private static func buildTomorrow(
        requiredOfficeDays: Int, officeDone: Int,
        offDays: Set<Date>, weeklyOffDays: Set<Int>,
        homeByDate: [Date: [WeatherHour]], officeByDate: [Date: [WeatherHour]],
        departureHour: Int, returnHour: Int,
        tomorrow: Date, calendar: Calendar
    ) -> DecisionResult? {
        let iso = WorkdayCalculator.isoWeekday(of: tomorrow, calendar: calendar)
        guard !weeklyOffDays.contains(iso), !offDays.contains(tomorrow) else { return nil }

        let key = DateKeys.dayKey(tomorrow, calendar: calendar)
        guard let home = homeByDate[key], !home.isEmpty else { return nil }
        let office = officeByDate[key] ?? home

        let workdays = WorkdayCalculator.workdayDates(
            from: tomorrow, weeklyOffDays: weeklyOffDays, offDays: offDays, calendar: calendar)
        let month = MonthMath(requiredOfficeDays: requiredOfficeDays,
                              officeDone: officeDone, remainingWorkdays: workdays.count)
        let score = CommuteForecast.dayScore(
            home: home, office: office, departureHour: departureHour, returnHour: returnHour)
        let futureKeys = workdays.filter { $0 > tomorrow }.map { DateKeys.dayKey($0, calendar: calendar) }
        let futureScores = CommuteForecast.futureBestScores(
            workdays: futureKeys, homeByDate: homeByDate, officeByDate: officeByDate,
            departureHour: departureHour, returnHour: returnHour)
        return DecisionEngine.recommend(today: score.score, month: month, futureBestScores: futureScores)
    }

    // MARK: - Month helpers

    static func offDays(in month: MonthRecord, calendar: Calendar) -> Set<Date> {
        Set(month.days
            .filter { $0.status == .holiday || $0.status == .vacation }
            .map { calendar.startOfDay(for: $0.date) })
    }

    static func isLogged(month: MonthRecord, date: Date, calendar: Calendar) -> Bool {
        let day = calendar.startOfDay(for: date)
        return month.days.contains {
            calendar.startOfDay(for: $0.date) == day && $0.status != .none
        }
    }

    /// Best-effort background refresh: fetch today's home forecast and update the
    /// cache so the evening notification / offline fallback see fresh data (P2).
    static func refreshTodayCache(settings: AppSettings, container: ModelContainer, now: Date = Date()) async {
        let client = WeatherClientFactory.make()
        guard let homeByDate = try? await client.fetchDailyHourly(
            latitude: settings.homeLat, longitude: settings.homeLng, forecastDays: forecastDays) else { return }
        cacheToday(homeByDate: homeByDate, now: now, calendar: .current, context: ModelContext(container))
    }

    // MARK: - Weather cache (offline fallback)

    private static func cacheToday(homeByDate: [Date: [WeatherHour]], now: Date, calendar: Calendar, context: ModelContext) {
        let key = DateKeys.dayKey(now, calendar: calendar)
        guard let hours = homeByDate[key], !hours.isEmpty else { return }
        let descriptor = FetchDescriptor<WeatherCache>(predicate: #Predicate { $0.date == key })
        if let existing = try? context.fetch(descriptor).first {
            existing.hourlyData = (try? JSONEncoder().encode(hours)) ?? existing.hourlyData
            existing.fetchedAt = now
        } else {
            context.insert(WeatherCache(date: key, hourly: hours, fetchedAt: now))
        }
        try? context.save()
    }

    private static func cachedToday(now: Date, calendar: Calendar, context: ModelContext) -> [WeatherHour]? {
        let key = DateKeys.dayKey(now, calendar: calendar)
        let descriptor = FetchDescriptor<WeatherCache>(predicate: #Predicate { $0.date == key })
        guard let cache = try? context.fetch(descriptor).first, !cache.hourly.isEmpty else { return nil }
        return cache.hourly
    }
}
