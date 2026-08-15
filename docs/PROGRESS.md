# officast 구현 진행상황

> Hybrid Commute Optimizer. 계획: `docs/CEO-PLAN.md`, 명세: `docs/SPEC.md`
> 최종 업데이트: 2026-08-15

## 요약

| Phase | 상태 | 검증 |
|-------|------|------|
| P1a Core Loop | ✅ 완료 | 빌드/테스트/실행/현지화 |
| P1b Polish | ✅ 완료 | 빌드/테스트/번들 |
| P2 Enhancements | ✅ 완료 | 빌드/테스트/plist/실행 |
| P3 Widget | ⬜ 미착수 | — |
| P4 Report | ✅ 완료 | 빌드/테스트/실행(탭 렌더) |

- 테스트: **61개 통과** (전부 순수 로직 + 인메모리 SwiftData)
- 브랜치: `feature/p1-core-loop` (미푸시), 커밋 4개
- 배포 타겟 iOS 26.5, Swift Testing, 동기화 폴더 그룹(Xcode 16)

## 커밋

```
907dbb3 기능: P2 Enhancements (아침 알림 + BGTaskScheduler)
4076407 기능: P1 코어 루프 구현 (P1a + P1b)
922310d 문서: SPEC·CEO 계획 추가, 앱 아이콘 및 .gitignore 설정
8deb087 Initial Commit
```

## 완료 상세

### P1a Core Loop
- **Domain/** (순수, 골든 테스트): `CommuteScorer`(§3), `MonthMath`+`WorkdayCalculator`(§2/C6), `DecisionEngine`(§4 + E7 미래 예보 **양방향 보정**), `CommuteModels`
- **Data/**: SwiftData 모델(`MonthRecord`/`DayRecord`/`WeatherCache`, 스냅샷 필드), `AppSettings`(UserDefaults), `WeatherService`(Open-Meteo, `WeatherFetching`, `ms`·`timezone=auto`)
- **Features/**: `CommuteForecast`(D4 보간), `DashboardModel`(오케스트레이션+캐시 fallback), `DateKeys`, `MonthRepository`, `LocationSearchModel`(MKLocalSearch 2단계), `NotificationScheduler`+`PendingCheckIn`, `AppNotificationDelegate`, `RecommendationPresentation`
- **Views/**: 온보딩/대시보드/캘린더/설정 + 루트 게이트, `LocationPickerField`, `WeekdaySelector`
- **l10n**: `Localizable.xcstrings` (ja+ko+en), knownRegions에 ja/ko 등록

### P1b Polish
- `PrivacyInfo.xcprivacy`: 추적 없음, 수집 없음, UserDefaults required-reason(`CA92.1`)
- 체크인 시 날씨 스냅샷: `WeatherSnapshot` 헬퍼 → `MonthRepository.setStatus`가 출근/재택날에만 저장(휴일/휴가 제외). 캘린더/알림 경로 공유

### P2 Enhancements
- 아침 알림(E2): 출발 30분 전, foreground/갱신 시 1회성 등록, 본문에 추천 (best-effort)
- BGTaskScheduler(C4): 저녁 예보 갱신 등록/스케줄. `Info.plist`(루트) `UIBackgroundModes`+`BGTaskSchedulerPermittedIdentifiers`
- l10n en: 소스 언어로 이미 전 키 포함

## 알려진 한계 (정직 기록)

1. **알림 체크인**: 배너 액션 → UserDefaults 대기 저장 → 앱 활성화 시 SwiftData 반영. iOS dismiss 제약(C3)으로 실시간 아님.
2. **BGTaskScheduler**: iOS가 실행 시점·여부 결정하는 best-effort. 시뮬레이터에서 실제 백그라운드 실행 미검증(등록/스케줄만 확인).
3. **캐시 fallback**: 오프라인 시 "오늘 집 예보"만 사용(미래 비교 없이 임계값만).
4. **테마**: 기본 SwiftUI 스타일(승인). 색상 폴리시는 dogfooding 후 별도.
5. **UI 자동화 테스트 없음**: 순수 로직 단위 테스트 + 빌드/실행 스모크로 검증.

### P4 Report
- `Domain/MonthlyReport.swift`(순수, 골든 테스트): 이번 달 출근 진도·재택 횟수·**"궂은 통근 예보일 재택 N회"** 집계. SwiftData 비의존(`(status, snapshot?)` 배열 입력), `roughCommuteThreshold=70`
- `Views/ReportView.swift`: 현재 월만(CalendarView와 동일). `@Query` → `MonthlyReport.from(...)` → `List`
- `ContentView`: 4번째 탭(`chart.bar`) 추가
- l10n ja/ko/en 7개 키(`report.*`) 추가
- **정직 기록**: snapshot이 `nil`인 날(P1b 이전/오프라인)은 궂은날 카운트에서 제외 → 지표가 실제보다 작게 보일 수 있어 오해 소지 있는 분모("N회 중") 미표기

## 남은 작업

### P3 Widget (미착수)
- App Groups PoC (공유 ModelContainer 또는 `UserDefaults(suiteName:)` fallback)
- WidgetKit small 위젯 (진도 링 + 추천 라벨), `WidgetCenter.reloadAllTimelines()`
- **주의**: 위젯 익스텐션 타겟 추가 → pbxproj 구조 작업 큼

