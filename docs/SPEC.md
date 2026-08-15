# Hybrid Commute Optimizer — MVP Spec (v1)

> A personal mobile app for hybrid workers who have a **mandatory office-attendance quota**.
> It tracks how many office days you still owe this month and, each day, recommends
> **office (full / AM-only / PM-only) vs. work-from-home** based on the weather over your
> commute — spending your office days on the good days and saving WFH for the bad ones.

---

## 1. Positioning

- **Platform:** iOS (SwiftUI, native).
- **User:** A single hybrid worker with a fixed monthly in-office requirement (e.g. "at least 40% of workdays in office", counted 1st→last of each month). Half-days (AM-office or PM-office) count as one full office day.
- **This is a passion / utility project.** Monetization is explicitly **not** a goal. A single banner ad is acceptable; there is **no paywall, no subscription, no IAP** in scope. Design decisions optimize for *usefulness to the builder* and *fun to build*, not revenue or DAU.
- **v1 is weather-only.** Live train-delay integration is deferred to v2 (see §9). Weather is the dominant, *forecastable* factor; train delays are real-time-only and add the most integration cost, so they are cut from v1.

### Non-goals (v1)
- No employer/HR side, no team features, no seat booking.
- No account, no cloud sync, no login. Everything is local.
- No automatic attendance detection (geofencing). Attendance is self-reported.
- No train / transit data.

---

## 2. Core Model

All math is per calendar month (1st → last day). Half-days count as **1** office day.

| Symbol | Meaning | Source |
|--------|---------|--------|
| `O` | Required office days this month | **User input** (a natural number), entered before the first log of the month |
| `officeDone` | Office days already logged this month | Derived from daily check-ins (full / AM / PM each = +1) |
| `R` | Remaining workdays, from the target day through month-end (inclusive) | Derived: calendar days minus weekends minus user-marked holidays/vacation |
| `oRemain` | Office days still owed | `max(0, O − officeDone)` |
| `slack` | Days you can still afford to WFH | `R − oRemain` |

**Design decision:** the app does **not** compute `O` from the 60% rule, holidays, and paid
leave — the user enters `O` directly. Company rounding rules and leave accounting vary and are
error-prone; a direct natural-number input removes an entire class of bugs. (Optional v2 helper:
"enter your workday count and we'll compute 40%.")

### Slack interpretation
- `slack < 0` → quota is already unreachable (over-WFH'd). Warn the user; recommend office every remaining day.
- `slack == 0` → every remaining workday **must** be office.
- `slack > 0` → you can WFH on `slack` of the remaining days; be selective.

---

## 3. Commute-Leg Scoring (weather-only, rule-based, no AI)

Misery is felt **while walking to/from the station**, not while sitting in the office. So we
score **commute legs**, not "morning" vs "afternoon" in the abstract. Three legs:

- **morningOut** — leaving home at the user's departure time (default 08:00)
- **midday** — the changeover leg used by half-days (~12:00)
- **eveningHome** — leaving the office at the user's return time (default 19:00)

For each leg, take the hourly forecast nearest that time and start from **100**, subtracting penalties:

| Factor | Condition → penalty |
|--------|--------------------|
| Precipitation probability | ≥80% → −40 · 60–80% → −25 · 40–60% → −12 |
| Precipitation intensity (preferred when available) | ≥4 mm/h (heavy) → −45 · light rain → −15 |
| Snow | any → −50 |
| Wind speed | ≥10 m/s → −20 · 7–10 m/s → −10 |
| Temperature | ≥33 °C → −15 · ≤2 °C → −12 |

Use the **larger** of the probability-based and intensity-based rain penalties (don't double-count).
Clamp the final leg score to `[0, 100]`. Higher = better commute.

> No machine learning is required for v1. "AI" enters only as an optional v2 personalization
> layer (learn the user's own threshold from their past choices).

---

## 4. Decision Engine

### 4.1 Option scores
Each attendance option is the **minimum** of its two commute legs (the worse leg dictates how bad the day feels):

- `fullDay = min(morningOut, eveningHome)`
- `amOnly  = min(morningOut, midday)`   *(commute out in the morning, home at midday)*
- `pmOnly  = min(midday, eveningHome)`   *(commute out at midday, home in the evening)*

`bestOption = argmax(fullDay, amOnly, pmOnly)`, with `bestScore` its value.

### 4.2 Threshold from slack
Let `officeRatio = oRemain / R` (fraction of remaining days that must be office).

```
T = 100 * (1 − officeRatio)
```

- `officeRatio = 1` (must office every remaining day) → `T = 0` → always office.
- `officeRatio` low (lots of slack) → high `T` → only office on a genuinely good day.

### 4.3 Recommendation
```
if slack <= 0:
    recommend OFFICE  (bestOption; warn if slack < 0)
elif bestScore >= T:
    recommend OFFICE  (bestOption)   # spend an office day on a good day
else:
    recommend WFH                    # save it for a worse day
```

This naturally produces the "you're behind on office days → go in while conditions are OK"
behavior: as the month progresses and `officeDone` lags, `officeRatio` rises, `T` falls, and
office recommendations become more frequent.

### 4.4 Half-day cheat code
Because a half-day still counts as a full office day, when the best option is a half-day
(`amOnly` or `pmOnly` beats `fullDay` by a meaningful margin) the app surfaces it explicitly:
*"Heavy rain this morning — go in for the afternoon only. Still counts, and you dodge the storm."*
This is the app's signature differentiator; no generic attendance app does it.

---

## 5. Check-in & Notification
- One local notification per day at **notifyTime** (default 21:00, user-editable, stored locally).
- The notification does double duty:
  1. **Log today:** tap 出社 (Full / AM / PM) or 在宅 → updates `officeDone`.
  2. **Preview tomorrow:** because v1 is weather-only, tomorrow is *forecastable*, so show tomorrow's recommendation right in the same view ("Tomorrow: PM-office recommended").
- Days can also be edited manually from the calendar (missed a night, etc.).

---

## 6. Screens (v1)

1. **Onboarding**
   - Home location (for weather; city or map pin).
   - Departure time / return time (defaults 08:00 / 19:00).
   - This month's required office days `O` (natural number).
   - Notification time (default 21:00). Weekly days off (default Sat/Sun).
2. **Home / Dashboard**
   - This month's progress: `officeDone / O`, remaining workdays `R`, `slack`.
   - Today's recommendation + tomorrow's recommendation, each with the reason (e.g. "80% rain at 08:00").
3. **Calendar (month)**
   - Weekends greyed out; tap a day to mark holiday / paid leave (adjusts `R`).
   - Each past day shows its logged status; tap to correct.
4. **Settings**
   - Edit all onboarding values; edit `O` for the current month; reset month.

---

## 7. Data Model (all local — UserDefaults / SwiftData)

```jsonc
// settings (single object)
{
  "homeLat": 35.5,
  "homeLng": 139.7,
  "departureTime": "08:00",
  "returnTime": "19:00",
  "notifyTime": "21:00",
  "weeklyOffDays": [6, 7]          // ISO weekday numbers
}

// per-month record, keyed by "YYYY-MM"
{
  "yearMonth": "2026-08",
  "requiredOfficeDays": 12,        // O
  "days": {
    "2026-08-01": "wfh",           // office_full | office_am | office_pm | wfh | holiday | vacation | none
    "2026-08-04": "office_full"
  }
}

// weather cache (per day, refreshed on app open / daily)
{
  "date": "2026-08-15",
  "hourly": [ { "hour": 8, "popPct": 80, "mmPerH": 3.1, "snow": false, "windMs": 4, "tempC": 31 } ]
}
```

`officeDone` and `R` are **derived** at read time, never stored directly (single source of truth = `days`).

---

## 8. Stack

- **UI:** SwiftUI
- **State:** @Observable / SwiftUI environment
- **Storage:** UserDefaults (settings) + JSON files or SwiftData (monthly records, weather cache)
- **Notifications:** UNUserNotificationCenter (local only, no push/APNs in v1)
- **Ads:** Google AdMob — one banner on the dashboard
- **Weather API:** any hourly forecast provider (e.g. Open-Meteo / OpenWeather / 気象庁-derived). Pull once per day (or on app open); cache locally. Pick a provider whose hourly fields include precipitation probability **and** intensity if possible.
- **l10n:** String Catalogs with `ja` + `ko` from day one; no hardcoded strings.
- **Architecture:** standard layering. The scoring + decision engine is the crown jewel and should be a pure, well-tested module with golden test cases for slack edge conditions.

---

## 9. v2+ Backlog (explicitly out of v1)

- **Train integration:** register with ODPT (free), map home/office nearest stations → lines, pull real-time 運行情報, add a train penalty to leg scores, and **re-run the morning-of recommendation** with live delays.
- Reflect pre-announced planned suspensions / construction in the night-before recommendation.
- **AI personalization:** learn the user's own threshold from past accept/override choices and auto-tune `T`.
- Monthly report + next-month simulation.
- Home-screen widget (iOS/Android) showing today's recommendation and progress.
- Optional geofence-based auto check-in.
- Helper input: enter workday count → auto-compute 40%.

---

## 10. Open Questions
1. Which weather provider? (Determines whether we get precipitation *intensity* or only *probability*, which changes the rain penalty branch.)
2. Should `fullDay` use `min` of legs (conservative, chosen here) or a blended `0.5·avg + 0.5·min`? Revisit after dogfooding.
3. Half-day surfacing threshold: how much must a half-day beat `fullDay` by before we recommend it over a full day? (Start ~15 points, tune by feel.)
4. Should the daily notification also fire on days already logged? (Default: no.)
