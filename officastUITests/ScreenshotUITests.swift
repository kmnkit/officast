//
//  ScreenshotUITests.swift
//  officastUITests
//
//  App Store 마케팅 스크린샷용 결정론적 캡처. 기존 헤르메틱 하네스(UITEST env)로
//  각 화면을 시딩한 뒤 fastlane `snapshot`으로 PNG를 저장한다. fastlane snapshot이
//  `en-US`, `ja` 각 로케일로 이 클래스를 재실행하며, `setupSnapshot`이 로케일을
//  launchArguments로 주입한다(launch()는 launchEnvironment만 건드리므로 공존).
//

import XCTest

final class ScreenshotUITests: UITestCase {

    /// 월 중순 평일로 "오늘"을 고정 — 잔여 근무일·결정 임계값을 날짜 무관하게 안정화.
    private let fixedToday = "2026-06-15"

    // MARK: - 01 Dashboard (히어로): 날씨 기반 추천 + 월 진행 상황

    @MainActor
    func test01Dashboard() {
        setupSnapshot(app)
        launch([
            "UITEST_WEATHER": "sunny",
            "UITEST_TODAY": fixedToday,
            "UITEST_QUOTA": "explicit",
            "UITEST_REQUIRED_DAYS": "10",
            "UITEST_PRIOR_COUNT": "6",
        ])
        waitFor("dashboard.progress.officeDone")
        snapshot("01-dashboard")
    }

    // MARK: - 02 반차 치트 코드: 오전 맑음/오후 비 → 오전만 출근 추천 + 반차 팁

    @MainActor
    func test02HalfDay() {
        setupSnapshot(app)
        // balanced 쿼터라야 am_clear_pm_rain의 officeAM 결정이 결정론적으로 보장된다.
        launch([
            "UITEST_WEATHER": "am_clear_pm_rain",
            "UITEST_TODAY": fixedToday,
        ])
        waitFor("dashboard.today.option.officeAM")
        snapshot("02-halfday")
    }

    // MARK: - 03 Report: 피한 나쁜 통근(회피 일수) = 가치 증명

    @MainActor
    func test03Report() {
        setupSnapshot(app)
        // ReportView는 실제 Date() 월을 표시하므로 UITEST_TODAY를 지정하지 않는다 —
        // 시더 월과 리포트 표시 월을 일치시켜 시드된 집계가 실제로 보이게 한다.
        launch([
            "UITEST_WEATHER": "sunny",
            "UITEST_QUOTA": "explicit",
            "UITEST_REQUIRED_DAYS": "10",
            "UITEST_SEED_DAYS": "office_full:80,office_full:70,wfh:20,wfh:90,wfh:40",
            "UITEST_TAB": "report",
        ])
        waitFor("report.roughDaysAvoided")
        snapshot("03-report")
    }

    // MARK: - 04 Calendar: 월간 출근 현황 한눈에

    @MainActor
    func test04Calendar() {
        setupSnapshot(app)
        // CalendarView는 AppClock이 아닌 실제 Date()로 월을 표시하므로 UITEST_TODAY를
        // 지정하지 않는다 — 시더 월(AppClock.now)과 캘린더 표시 월(실제 월)을 일치시켜
        // 시드된 날짜가 그리드에 보이도록 한다.
        launch([
            "UITEST_WEATHER": "sunny",
            "UITEST_QUOTA": "explicit",
            "UITEST_REQUIRED_DAYS": "10",
            "UITEST_SEED_DAYS": "office_full:80,office_full:70,wfh:20,wfh:90,wfh:40",
            "UITEST_TAB": "calendar",
        ])
        // 표시 월에 항상 존재하는 오늘 셀이 그려질 때까지 대기(상태 선택 다이얼로그와 혼동 금지).
        waitFor(dayIdentifier())
        snapshot("04-calendar")
    }

    // MARK: - 05 Settings: 쿼터만 정하면 끝

    @MainActor
    func test05Settings() {
        setupSnapshot(app)
        // SettingsView의 "이번 달" 섹션은 실제 Date() 월의 MonthRecord가 있어야 렌더된다.
        // UITEST_TODAY를 지정하면 시더가 다른 월에 레코드를 만들어 섹션이 사라지므로 생략.
        launch([
            "UITEST_WEATHER": "sunny",
            "UITEST_QUOTA": "explicit",
            "UITEST_REQUIRED_DAYS": "10",
            "UITEST_TAB": "settings",
        ])
        // requiredDays는 stepper 컨트롤 — .any firstMatch 대신 steppers 쿼리로 대기.
        let stepper = app.steppers["settings.requiredDays"]
        XCTAssertTrue(stepper.waitForExistence(timeout: 12), "settings stepper not found")
        snapshot("05-settings")
    }
}
