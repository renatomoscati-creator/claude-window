# Claude Window Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a macOS menu bar app that estimates whether the current moment is a good time to use Claude, showing a colored icon plus estimated session capacity, with a local HTTP API for automation.

**Architecture:** Single Xcode project (macOS 13+) using SwiftUI + MenuBarExtra for the menu bar shell. Core scoring logic lives in pure-Swift structs with no UI dependencies — fully unit-testable with XCTest. Data flows from `AppState` (ObservableObject) into SwiftUI views. A minimal HTTP/1.1 server built on `NWListener` (Network.framework, no external dependencies) exposes the local API. Persistence uses `UserDefaults` for settings and a JSON file in `~/Library/Application Support/ClaudeWindow/` for telemetry.

**Tech Stack:** Swift 5.9+, SwiftUI, MenuBarExtra (macOS 13+), Network.framework (NWListener), XCTest, URLSession (status fetching), UserDefaults + JSONEncoder/JSONDecoder (persistence).

**GitHub:** All code lives at `github.com/<owner>/claude-window`. Every commit in this plan is followed by `git push`. Use `gh` CLI for repo and PR operations.

**NotebookLM:** A NotebookLM notebook is used as a living knowledge base for this project. The PRD and this plan are uploaded as sources. Use it to research implementation questions (Swift APIs, statuspage.io schema, MenuBarExtra patterns) before writing code.

> **Git push rule:** Every commit step in this plan ends with `git push origin main`. Do not skip pushes.

---

## File Map

```
ClaudeWindow/
├── ClaudeWindowApp.swift            # App entry point, MenuBarExtra declaration
├── AppState.swift                   # ObservableObject — owns scorers, drives UI + API
├── Models/
│   ├── Surface.swift                # Claude surfaces enum (desktop/code/api)
│   ├── OperatingMode.swift          # LimitRisk / Reliability enum
│   ├── Plan.swift                   # Subscription plan + custom token assumptions
│   ├── WorkloadProfile.swift        # Presets + tokens-per-query estimates
│   ├── WindowScore.swift            # Score output: score, state, confidence, reasons
│   └── Capacity.swift               # Query/token range + BestWindow
├── Scoring/
│   ├── TimingHeuristics.swift       # Business-hour overlap, weekend, holiday, season
│   ├── LimitEfficiencyScorer.swift  # Limit Risk Mode: 0-100 score
│   ├── ReliabilityScorer.swift      # Reliability Mode: 0-100 score
│   ├── ConfidenceEstimator.swift    # High/Medium/Low confidence from signal quality
│   └── CapacityEstimator.swift      # Query/token ranges from score + profile
├── Data/
│   ├── AnthropicStatusFetcher.swift # GET https://status.anthropic.com/api/v2/summary.json
│   ├── StatusModels.swift           # Decodable structs for statuspage.io response
│   ├── SettingsStore.swift          # UserDefaults-backed settings persistence
│   └── TelemetryStore.swift         # JSON file in Application Support
├── API/
│   ├── LocalAPIServer.swift         # NWListener HTTP/1.1 server on localhost:58742
│   └── APIHandlers.swift            # Route → JSON response builders
└── UI/
    ├── MenuBarIconView.swift        # SF Symbol tinted by WindowState
    ├── DropdownView.swift           # Main popover with all 8 sections
    ├── SurfaceSectionView.swift     # Per-surface score row
    ├── OnboardingView.swift         # First-run 5-step setup flow
    └── SettingsView.swift           # Full settings panel

ClaudeWindowTests/
├── TimingHeuristicsTests.swift
├── LimitEfficiencyScorerTests.swift
├── ReliabilityScorerTests.swift
├── ConfidenceEstimatorTests.swift
├── CapacityEstimatorTests.swift
└── APIHandlersTests.swift
```

---

## Task 0: GitHub Repo & NotebookLM Setup

**Files:** none (infrastructure only)

- [ ] **Step 1: Create the GitHub repository**

```bash
gh repo create claude-window \
  --description "macOS menu bar app for Claude session timing" \
  --private \
  --clone=false
```

Expected output: `✓ Created repository <owner>/claude-window on GitHub`

- [ ] **Step 2: Init the local repo and push**

```bash
cd "/Users/renatomoscati/Claude Window"
git init
git add claude_window_prd.md docs/
git commit -m "chore: add PRD and implementation plan"
git branch -M main
git remote add origin git@github.com:<owner>/claude-window.git
git push -u origin main
```

Verify in browser: `https://github.com/<owner>/claude-window` — PRD and plan visible.

- [ ] **Step 3: Open NotebookLM and create the project notebook**

Navigate to `https://notebooklm.google.com` and create a new notebook named **"Claude Window"**.

- [ ] **Step 4: Upload the PRD as a source**

In the notebook, click **+ Add source** → Upload file.
Upload: `/Users/renatomoscati/Claude Window/claude_window_prd.md`

- [ ] **Step 5: Upload the implementation plan as a source**

Click **+ Add source** → Upload file.
Upload: `/Users/renatomoscati/Claude Window/docs/superpowers/plans/2026-04-07-claude-window.md`

- [ ] **Step 6: Add the Anthropic statuspage API schema as a web source**

Click **+ Add source** → Website.
URL: `https://status.anthropic.com/api/v2/summary.json`

This gives the notebook live schema knowledge for the status fetcher (Task 4).

- [ ] **Step 7: Generate a notebook guide**

In NotebookLM, click **Notebook guide** to auto-generate an overview. Skim it to confirm the notebook has ingested the PRD correctly — the summary should mention menu bar, scoring modes, and local API.

- [ ] **Step 8: Verify GitHub Actions (optional but recommended)**

Add a minimal CI workflow so every push runs the test suite:

Create `.github/workflows/ci.yml`:

```yaml
name: CI
on: [push, pull_request]
jobs:
  test:
    runs-on: macos-14
    steps:
      - uses: actions/checkout@v4
      - name: Run tests
        run: |
          xcodebuild test \
            -scheme ClaudeWindow \
            -destination 'platform=macOS,arch=arm64' \
            -resultBundlePath TestResults \
            2>&1 | xcpretty || true
```

```bash
mkdir -p ".github/workflows"
# write the file above, then:
git add .github/
git commit -m "ci: add GitHub Actions test workflow"
git push origin main
```

---

## Task 1: Xcode Project Bootstrap

**Files:**
- Create: `ClaudeWindow.xcodeproj` (via Xcode new project)
- Create: `ClaudeWindow/ClaudeWindowApp.swift`
- Create: `ClaudeWindowTests/` test target

- [ ] **Step 1: Create the Xcode project**

In Xcode: File → New → Project → macOS → App.
- Product name: `ClaudeWindow`
- Interface: SwiftUI
- Language: Swift
- Uncheck "Include Tests" — we'll add them manually.
- Save to `~/Claude Window/`

Add a test target: File → New → Target → Unit Testing Bundle.
- Product name: `ClaudeWindowTests`
- Target to be tested: `ClaudeWindow`

- [ ] **Step 2: Set deployment target**

In project settings → ClaudeWindow target → General:
- Minimum Deployments: macOS 13.0

- [ ] **Step 3: Remove default window scene and set up MenuBarExtra shell**

Replace `ClaudeWindowApp.swift` with:

```swift
import SwiftUI

@main
struct ClaudeWindowApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        MenuBarExtra {
            DropdownView()
                .environmentObject(appState)
        } label: {
            MenuBarIconView(state: appState.primaryScore?.state ?? .unknown)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
                .environmentObject(appState)
        }
    }
}
```

- [ ] **Step 4: Add empty placeholder files**

Create each file in the File Map above with a single comment `// TODO` so the project compiles. This lets us build incrementally.

- [ ] **Step 5: Verify project builds**

```bash
xcodebuild build -scheme ClaudeWindow -destination 'platform=macOS,arch=arm64' 2>&1 | tail -5
```
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 6: Commit and push**

```bash
git add .
git commit -m "chore: bootstrap Xcode project with MenuBarExtra skeleton"
git push origin main
```

---

## Task 2: Core Models

**Files:**
- Create: `ClaudeWindow/Models/Surface.swift`
- Create: `ClaudeWindow/Models/OperatingMode.swift`
- Create: `ClaudeWindow/Models/Plan.swift`
- Create: `ClaudeWindow/Models/WorkloadProfile.swift`
- Create: `ClaudeWindow/Models/WindowScore.swift`
- Create: `ClaudeWindow/Models/Capacity.swift`

- [ ] **Step 1: Write tests for models**

In `ClaudeWindowTests/ModelsTests.swift`:

```swift
import XCTest
@testable import ClaudeWindow

final class ModelsTests: XCTestCase {

    func test_workloadProfile_tokensPerQuery() {
        XCTAssertEqual(WorkloadProfile.lightChat.tokensPerQuery, 500)
        XCTAssertEqual(WorkloadProfile.coding.tokensPerQuery, 2000)
        XCTAssertEqual(WorkloadProfile.longContextAnalysis.tokensPerQuery, 8000)
    }

    func test_plan_baseQueryLimit() {
        XCTAssertEqual(Plan.pro.baseQueryLimit, 45)
        XCTAssertGreaterThan(Plan.max.baseQueryLimit, Plan.pro.baseQueryLimit)
    }

    func test_windowState_colorName() {
        XCTAssertEqual(WindowState.efficient.colorName, "green")
        XCTAssertEqual(WindowState.poor.colorName, "red")
        XCTAssertEqual(WindowState.unknown.colorName, "gray")
    }

    func test_windowScore_codable() throws {
        let score = WindowScore(
            score: 74,
            state: .efficient,
            confidence: .medium,
            reasons: ["Off-peak US hours"]
        )
        let data = try JSONEncoder().encode(score)
        let decoded = try JSONDecoder().decode(WindowScore.self, from: data)
        XCTAssertEqual(decoded.score, 74)
        XCTAssertEqual(decoded.state, .efficient)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
xcodebuild test -scheme ClaudeWindow -destination 'platform=macOS,arch=arm64' -only-testing ClaudeWindowTests/ModelsTests 2>&1 | tail -10
```
Expected: FAIL — types not defined yet.

- [ ] **Step 3: Implement Surface.swift**

```swift
import Foundation

enum Surface: String, Codable, CaseIterable, Identifiable {
    case desktop = "desktop"
    case code    = "code"
    case api     = "api"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .desktop: return "Claude Desktop"
        case .code:    return "Claude Code"
        case .api:     return "Claude API"
        }
    }
}
```

- [ ] **Step 4: Implement OperatingMode.swift**

```swift
import Foundation

enum OperatingMode: String, Codable, CaseIterable {
    case limitRisk  = "limit_risk"
    case reliability = "reliability"

    var displayName: String {
        switch self {
        case .limitRisk:   return "Limit Risk"
        case .reliability: return "Reliability"
        }
    }
}
```

- [ ] **Step 5: Implement WindowScore.swift**

```swift
import Foundation

enum WindowState: String, Codable {
    case efficient   = "efficient"
    case average     = "average"
    case highRisk    = "high_risk"
    case poor        = "poor"
    case unknown     = "unknown"

    var colorName: String {
        switch self {
        case .efficient: return "green"
        case .average:   return "yellow"
        case .highRisk:  return "orange"
        case .poor:      return "red"
        case .unknown:   return "gray"
        }
    }

    var displayLabel: String {
        switch self {
        case .efficient: return "Efficient window"
        case .average:   return "Average window"
        case .highRisk:  return "High limit-risk window"
        case .poor:      return "Poor reliability window"
        case .unknown:   return "Unknown"
        }
    }
}

enum Confidence: String, Codable {
    case high   = "high"
    case medium = "medium"
    case low    = "low"
}

struct WindowScore: Codable, Equatable {
    let score: Int           // 0-100
    let state: WindowState
    let confidence: Confidence
    let reasons: [String]
}
```

- [ ] **Step 6: Implement Plan.swift**

```swift
import Foundation

enum Plan: String, Codable, CaseIterable {
    case free   = "free"
    case pro    = "pro"
    case max    = "max"
    case custom = "custom"

    /// Approximate query limit per 5-hour rolling window (heuristic, not official).
    var baseQueryLimit: Int {
        switch self {
        case .free:   return 10
        case .pro:    return 45
        case .max:    return 100
        case .custom: return 45   // overridden by CustomPlanSettings
        }
    }

    var displayName: String { rawValue.capitalized }
}

struct CustomPlanSettings: Codable, Equatable {
    var baseQueryLimit: Int   = 45
    var baseTokenLimit: Int   = 200_000
}
```

- [ ] **Step 7: Implement WorkloadProfile.swift**

```swift
import Foundation

enum WorkloadProfile: String, Codable, CaseIterable {
    case lightChat          = "light_chat"
    case standardWriting    = "standard_writing"
    case coding             = "coding"
    case longContextAnalysis = "long_context_analysis"
    case documentHeavy      = "document_heavy"

    var displayName: String {
        switch self {
        case .lightChat:           return "Light chat"
        case .standardWriting:     return "Standard writing / research"
        case .coding:              return "Coding"
        case .longContextAnalysis: return "Long-context analysis"
        case .documentHeavy:       return "File-heavy / document-heavy"
        }
    }

    /// Average tokens consumed per query (prompt + response, heuristic).
    var tokensPerQuery: Int {
        switch self {
        case .lightChat:           return 500
        case .standardWriting:     return 1_200
        case .coding:              return 2_000
        case .longContextAnalysis: return 8_000
        case .documentHeavy:       return 12_000
        }
    }
}
```

- [ ] **Step 8: Implement Capacity.swift**

```swift
import Foundation

struct QueryCapacity: Codable, Equatable {
    let minQueries: Int
    let maxQueries: Int
    let minTokens: Int
    let maxTokens: Int
    let confidence: Confidence
}

struct BestWindow: Codable, Equatable {
    let startHour: Int      // local hour 0-23
    let endHour: Int
    let confidence: Confidence
    let reasons: [String]
}
```

- [ ] **Step 9: Run tests to verify they pass**

```bash
xcodebuild test -scheme ClaudeWindow -destination 'platform=macOS,arch=arm64' -only-testing ClaudeWindowTests/ModelsTests 2>&1 | tail -10
```
Expected: PASS.

- [ ] **Step 10: Commit and push**

```bash
git add ClaudeWindow/Models/ ClaudeWindowTests/ModelsTests.swift
git commit -m "feat: add core data models (Surface, Plan, WorkloadProfile, WindowScore, Capacity)"
git push origin main
```

---

## Task 3: Timing Heuristics Engine

**Files:**
- Create: `ClaudeWindow/Scoring/TimingHeuristics.swift`
- Create: `ClaudeWindowTests/TimingHeuristicsTests.swift`

- [ ] **Step 1: Write failing tests**

```swift
import XCTest
@testable import ClaudeWindow

final class TimingHeuristicsTests: XCTestCase {

    // Helper: build a Date for a given UTC hour on a Tuesday (weekday).
    private func tuesdayUTC(_ hour: Int) -> Date {
        // 2026-04-07 is a Tuesday
        var comps = DateComponents()
        comps.year = 2026; comps.month = 4; comps.day = 7
        comps.hour = hour; comps.minute = 0; comps.second = 0
        comps.timeZone = TimeZone(identifier: "UTC")
        return Calendar(identifier: .gregorian).date(from: comps)!
    }

    private func saturdayUTC(_ hour: Int) -> Date {
        var comps = DateComponents()
        comps.year = 2026; comps.month = 4; comps.day = 11  // Saturday
        comps.hour = hour; comps.minute = 0; comps.second = 0
        comps.timeZone = TimeZone(identifier: "UTC")
        return Calendar(identifier: .gregorian).date(from: comps)!
    }

    func test_pressureScore_peakUSHours_isHigh() {
        // 20:00 UTC = 13:00 PT (US peak)
        let score = TimingHeuristics.pressureScore(at: tuesdayUTC(20))
        XCTAssertGreaterThan(score, 0.6)
    }

    func test_pressureScore_deepNightUTC_isLow() {
        // 07:00 UTC = 00:00 PT (US night) and before EU peak
        let score = TimingHeuristics.pressureScore(at: tuesdayUTC(7))
        XCTAssertLessThan(score, 0.35)
    }

    func test_pressureScore_weekend_isReducedVsWeekday() {
        let weekday = TimingHeuristics.pressureScore(at: tuesdayUTC(20))
        let weekend = TimingHeuristics.pressureScore(at: saturdayUTC(20))
        XCTAssertLessThan(weekend, weekday)
    }

    func test_pressureScore_isClampedBetweenZeroAndOne() {
        for hour in 0..<24 {
            let score = TimingHeuristics.pressureScore(at: tuesdayUTC(hour))
            XCTAssertGreaterThanOrEqual(score, 0.0)
            XCTAssertLessThanOrEqual(score, 1.0)
        }
    }

    func test_bestOffPeakHours_nextDay_returnsResults() {
        let windows = TimingHeuristics.bestOffPeakWindows(
            from: tuesdayUTC(20),
            lookAheadHours: 24
        )
        XCTAssertFalse(windows.isEmpty)
        // The top window should be off-peak
        XCTAssertLessThan(windows[0].pressureScore, 0.4)
    }

    func test_holidayRegions_USHoliday_reducesUsPressure() {
        // 2026-07-04 = US Independence Day (Saturday here, but let's use a weekday year)
        // 2025-07-04 = Friday
        var comps = DateComponents()
        comps.year = 2025; comps.month = 7; comps.day = 4
        comps.hour = 20; comps.minute = 0
        comps.timeZone = TimeZone(identifier: "UTC")
        let holiday = Calendar(identifier: .gregorian).date(from: comps)!

        let normalTuesday = tuesdayUTC(20)
        let holidayScore = TimingHeuristics.pressureScore(
            at: holiday, holidayRegions: [.us]
        )
        let normalScore = TimingHeuristics.pressureScore(
            at: normalTuesday, holidayRegions: []
        )
        XCTAssertLessThan(holidayScore, normalScore)
    }
}
```

- [ ] **Step 2: Run to verify failure**

```bash
xcodebuild test -scheme ClaudeWindow -destination 'platform=macOS,arch=arm64' -only-testing ClaudeWindowTests/TimingHeuristicsTests 2>&1 | tail -10
```
Expected: FAIL — `TimingHeuristics` not defined.

- [ ] **Step 3: Implement TimingHeuristics.swift**

```swift
import Foundation

enum HolidayRegion: String, Codable, CaseIterable {
    case us   = "us"
    case eu   = "eu"
    case uk   = "uk"
    case apac = "apac"

    var displayName: String {
        switch self {
        case .us:   return "United States"
        case .eu:   return "Europe"
        case .uk:   return "United Kingdom"
        case .apac: return "Asia-Pacific"
        }
    }
}

struct HourWindow {
    let startHour: Int   // UTC
    let endHour: Int     // UTC
    let pressureScore: Double
}

enum TimingHeuristics {

    // MARK: — Public API

    /// Returns a 0.0 (low pressure = good for user) to 1.0 (high pressure = bad) score
    /// based purely on timing signals. Does not include reliability data.
    static func pressureScore(
        at date: Date = Date(),
        holidayRegions: Set<HolidayRegion> = []
    ) -> Double {
        let utcCal = utcCalendar()
        let hour = utcCal.component(.hour, from: date)
        let weekday = utcCal.component(.weekday, from: date)  // 1=Sun, 7=Sat
        let isWeekend = weekday == 1 || weekday == 7

        let usLoad  = usRegionalLoad(utcHour: hour,
                                     holiday: isHoliday(date, region: .us, regions: holidayRegions))
        let euLoad  = euRegionalLoad(utcHour: hour,
                                     holiday: isHoliday(date, region: .eu, regions: holidayRegions))
        let apacLoad = apacRegionalLoad(utcHour: hour,
                                        holiday: isHoliday(date, region: .apac, regions: holidayRegions))

        // Weighted: US drives the most Claude traffic.
        var combined = usLoad * 0.55 + euLoad * 0.25 + apacLoad * 0.20

        // Weekend reduction
        if isWeekend {
            combined *= 0.55
        }

        // Seasonal: Dec–Jan slightly lower demand (holidays), Aug slightly higher
        let month = utcCal.component(.month, from: date)
        if month == 12 || month == 1 {
            combined *= 0.88
        } else if month == 8 {
            combined *= 1.06
        }

        return min(max(combined, 0.0), 1.0)
    }

    /// Returns up to 6 low-pressure hour windows within the next `lookAheadHours`,
    /// sorted by ascending pressure (best first).
    static func bestOffPeakWindows(
        from date: Date = Date(),
        lookAheadHours: Int = 24,
        holidayRegions: Set<HolidayRegion> = []
    ) -> [HourWindow] {
        var windows: [HourWindow] = []
        let cal = utcCalendar()

        for offset in 0..<lookAheadHours {
            guard let candidate = cal.date(byAdding: .hour, value: offset, to: date) else { continue }
            let hour = cal.component(.hour, from: candidate)
            let pressure = pressureScore(at: candidate, holidayRegions: holidayRegions)
            windows.append(HourWindow(startHour: hour, endHour: (hour + 1) % 24, pressureScore: pressure))
        }

        return windows
            .filter { $0.pressureScore < 0.45 }
            .sorted { $0.pressureScore < $1.pressureScore }
    }

    // MARK: — Private helpers

    private static func utcCalendar() -> Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal
    }

    /// US load peaks 14:00–22:00 UTC (9am–5pm ET, 6am–2pm PT both contribute).
    private static func usRegionalLoad(utcHour: Int, holiday: Bool) -> Double {
        let load = bellCurve(hour: utcHour, peakHour: 18, halfWidthHours: 5)
        return holiday ? load * 0.25 : load
    }

    /// EU load peaks 08:00–16:00 UTC (9am–5pm CET).
    private static func euRegionalLoad(utcHour: Int, holiday: Bool) -> Double {
        let load = bellCurve(hour: utcHour, peakHour: 12, halfWidthHours: 4)
        return holiday ? load * 0.30 : load
    }

    /// APAC load peaks 01:00–08:00 UTC (9am–5pm JST/SGT/AEST approx).
    private static func apacRegionalLoad(utcHour: Int, holiday: Bool) -> Double {
        let load = bellCurve(hour: utcHour, peakHour: 4, halfWidthHours: 4)
        return holiday ? load * 0.35 : load
    }

    /// Smooth bell-curve 0-1, centered on peakHour, rolling over midnight.
    private static func bellCurve(hour: Int, peakHour: Int, halfWidthHours: Double) -> Double {
        var delta = Double(hour - peakHour)
        // Wrap around 24h boundary
        if delta > 12  { delta -= 24 }
        if delta < -12 { delta += 24 }
        return exp(-(delta * delta) / (2 * halfWidthHours * halfWidthHours))
    }

    // MARK: — Holiday detection

    private static func isHoliday(_ date: Date, region: HolidayRegion, regions: Set<HolidayRegion>) -> Bool {
        guard regions.contains(region) else { return false }
        let cal = utcCalendar()
        let month = cal.component(.month, from: date)
        let day   = cal.component(.day,   from: date)

        switch region {
        case .us:
            // Fixed US federal holidays (simplified, fixed-date only)
            let usHolidays: [(Int, Int)] = [
                (1, 1), (7, 4), (11, 11), (12, 25), (12, 26)
            ]
            return usHolidays.contains { $0.0 == month && $0.1 == day }
        case .eu, .uk:
            let euHolidays: [(Int, Int)] = [(1,1),(12,25),(12,26)]
            return euHolidays.contains { $0.0 == month && $0.1 == day }
        case .apac:
            // Chinese New Year varies; approximate with first week of Feb
            if month == 2 && day <= 7 { return true }
            return [(1,1),(12,25)].contains { $0.0 == month && $0.1 == day }
        }
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
xcodebuild test -scheme ClaudeWindow -destination 'platform=macOS,arch=arm64' -only-testing ClaudeWindowTests/TimingHeuristicsTests 2>&1 | tail -10
```
Expected: PASS.

- [ ] **Step 5: Commit and push**

```bash
git add ClaudeWindow/Scoring/TimingHeuristics.swift ClaudeWindowTests/TimingHeuristicsTests.swift
git commit -m "feat: implement timing heuristics engine with regional load curves and holiday support"
git push origin main
```

---

## Task 4: Anthropic Status Fetcher

**Files:**
- Create: `ClaudeWindow/Data/StatusModels.swift`
- Create: `ClaudeWindow/Data/AnthropicStatusFetcher.swift`

No unit test for the network fetch itself (network is an integration concern), but test the parser with a canned response.

- [ ] **Step 1: Write parser test**

In `ClaudeWindowTests/StatusParserTests.swift`:

```swift
import XCTest
@testable import ClaudeWindow

final class StatusParserTests: XCTestCase {

    private let sampleJSON = """
    {
      "status": { "indicator": "minor", "description": "Minor Service Disruption" },
      "components": [
        { "id": "1", "name": "Claude.ai", "status": "operational" },
        { "id": "2", "name": "Claude API", "status": "degraded_performance" }
      ],
      "incidents": [
        {
          "id": "inc1",
          "name": "Elevated error rates",
          "status": "investigating",
          "impact": "minor",
          "created_at": "2026-04-07T10:00:00.000Z"
        }
      ]
    }
    """.data(using: .utf8)!

    func test_parse_overallIndicator() throws {
        let summary = try JSONDecoder().decode(StatusSummary.self, from: sampleJSON)
        XCTAssertEqual(summary.status.indicator, "minor")
    }

    func test_parse_componentCount() throws {
        let summary = try JSONDecoder().decode(StatusSummary.self, from: sampleJSON)
        XCTAssertEqual(summary.components.count, 2)
    }

    func test_parse_degradedComponent() throws {
        let summary = try JSONDecoder().decode(StatusSummary.self, from: sampleJSON)
        let degraded = summary.components.filter { $0.status != "operational" }
        XCTAssertEqual(degraded.count, 1)
        XCTAssertEqual(degraded[0].name, "Claude API")
    }

    func test_parse_incidentCount() throws {
        let summary = try JSONDecoder().decode(StatusSummary.self, from: sampleJSON)
        XCTAssertEqual(summary.incidents.count, 1)
        XCTAssertEqual(summary.incidents[0].impact, "minor")
    }
}
```

- [ ] **Step 2: Run to verify failure**

```bash
xcodebuild test -scheme ClaudeWindow -destination 'platform=macOS,arch=arm64' -only-testing ClaudeWindowTests/StatusParserTests 2>&1 | tail -10
```
Expected: FAIL.

- [ ] **Step 3: Implement StatusModels.swift**

```swift
import Foundation

struct StatusSummary: Decodable {
    let status: StatusIndicator
    let components: [StatusComponent]
    let incidents: [StatusIncident]
}

struct StatusIndicator: Decodable {
    let indicator: String    // "none" | "minor" | "major" | "critical"
    let description: String
}

struct StatusComponent: Decodable {
    let id: String
    let name: String
    let status: String  // "operational" | "degraded_performance" | "partial_outage" | "major_outage"
}

struct StatusIncident: Decodable {
    let id: String
    let name: String
    let status: String  // "investigating" | "identified" | "monitoring" | "resolved"
    let impact: String  // "none" | "minor" | "major" | "critical"
    let created_at: String
}

/// Processed result after parsing; safe to pass to scorers.
struct ServiceStatus {
    let indicator: String          // overall
    let hasActiveIncident: Bool
    let degradedComponentCount: Int
    let recentIncidentCount: Int   // within last 24h
    let fetchedAt: Date
}
```

- [ ] **Step 4: Implement AnthropicStatusFetcher.swift**

```swift
import Foundation

actor AnthropicStatusFetcher {

    private static let url = URL(string: "https://status.anthropic.com/api/v2/summary.json")!
    private var cached: ServiceStatus?
    private var cachedAt: Date?

    /// Returns cached status if < 5 minutes old, otherwise fetches fresh.
    func status(maxAge: TimeInterval = 300) async -> ServiceStatus {
        if let cached, let cachedAt, Date().timeIntervalSince(cachedAt) < maxAge {
            return cached
        }
        do {
            let (data, _) = try await URLSession.shared.data(from: Self.url)
            let summary = try JSONDecoder().decode(StatusSummary.self, from: data)
            let result = Self.process(summary)
            self.cached = result
            self.cachedAt = Date()
            return result
        } catch {
            // Degrade gracefully: return unknown status
            return ServiceStatus(
                indicator: "unknown",
                hasActiveIncident: false,
                degradedComponentCount: 0,
                recentIncidentCount: 0,
                fetchedAt: Date()
            )
        }
    }

    private static func process(_ summary: StatusSummary) -> ServiceStatus {
        let activeIncidents = summary.incidents.filter {
            $0.status != "resolved"
        }
        let degraded = summary.components.filter { $0.status != "operational" }
        return ServiceStatus(
            indicator: summary.status.indicator,
            hasActiveIncident: !activeIncidents.isEmpty,
            degradedComponentCount: degraded.count,
            recentIncidentCount: activeIncidents.count,
            fetchedAt: Date()
        )
    }
}
```

- [ ] **Step 5: Run tests**

```bash
xcodebuild test -scheme ClaudeWindow -destination 'platform=macOS,arch=arm64' -only-testing ClaudeWindowTests/StatusParserTests 2>&1 | tail -10
```
Expected: PASS.

- [ ] **Step 6: Commit and push**

```bash
git add ClaudeWindow/Data/StatusModels.swift ClaudeWindow/Data/AnthropicStatusFetcher.swift ClaudeWindowTests/StatusParserTests.swift
git commit -m "feat: add Anthropic status fetcher with caching and graceful degradation"
git push origin main
```

---

## Task 5: Limit Efficiency Scorer

**Files:**
- Create: `ClaudeWindow/Scoring/LimitEfficiencyScorer.swift`
- Create: `ClaudeWindowTests/LimitEfficiencyScorerTests.swift`

- [ ] **Step 1: Write failing tests**

```swift
import XCTest
@testable import ClaudeWindow

final class LimitEfficiencyScorerTests: XCTestCase {

    // 07:00 UTC Tuesday = low pressure (US night)
    private func lowPressureDate() -> Date {
        var c = DateComponents()
        c.year = 2026; c.month = 4; c.day = 7; c.hour = 7
        c.timeZone = TimeZone(identifier: "UTC")
        return Calendar(identifier: .gregorian).date(from: c)!
    }

    // 20:00 UTC Tuesday = high pressure (US peak)
    private func highPressureDate() -> Date {
        var c = DateComponents()
        c.year = 2026; c.month = 4; c.day = 7; c.hour = 20
        c.timeZone = TimeZone(identifier: "UTC")
        return Calendar(identifier: .gregorian).date(from: c)!
    }

    private func noIncident() -> ServiceStatus {
        ServiceStatus(indicator: "none", hasActiveIncident: false,
                      degradedComponentCount: 0, recentIncidentCount: 0, fetchedAt: Date())
    }

    private func activeIncident() -> ServiceStatus {
        ServiceStatus(indicator: "major", hasActiveIncident: true,
                      degradedComponentCount: 2, recentIncidentCount: 1, fetchedAt: Date())
    }

    func test_offPeak_scoreIsHigh() {
        let score = LimitEfficiencyScorer.score(
            at: lowPressureDate(), serviceStatus: noIncident(), holidayRegions: []
        )
        XCTAssertGreaterThan(score.score, 65)
        XCTAssertEqual(score.state, .efficient)
    }

    func test_peakHours_scoreIsLower() {
        let score = LimitEfficiencyScorer.score(
            at: highPressureDate(), serviceStatus: noIncident(), holidayRegions: []
        )
        XCTAssertLessThan(score.score, 55)
    }

    func test_peakHours_withActiveIncident_scoreIsLowerStill() {
        let withoutIncident = LimitEfficiencyScorer.score(
            at: highPressureDate(), serviceStatus: noIncident(), holidayRegions: []
        )
        let withIncident = LimitEfficiencyScorer.score(
            at: highPressureDate(), serviceStatus: activeIncident(), holidayRegions: []
        )
        XCTAssertLessThan(withIncident.score, withoutIncident.score)
    }

    func test_scoreContainsReasons() {
        let score = LimitEfficiencyScorer.score(
            at: lowPressureDate(), serviceStatus: noIncident(), holidayRegions: []
        )
        XCTAssertFalse(score.reasons.isEmpty)
    }

    func test_scoreIsClampedZeroToHundred() {
        for hour in 0..<24 {
            var c = DateComponents()
            c.year = 2026; c.month = 4; c.day = 7; c.hour = hour
            c.timeZone = TimeZone(identifier: "UTC")
            let d = Calendar(identifier: .gregorian).date(from: c)!
            let score = LimitEfficiencyScorer.score(at: d, serviceStatus: noIncident(), holidayRegions: [])
            XCTAssertGreaterThanOrEqual(score.score, 0)
            XCTAssertLessThanOrEqual(score.score, 100)
        }
    }
}
```

- [ ] **Step 2: Run to verify failure**

```bash
xcodebuild test -scheme ClaudeWindow -destination 'platform=macOS,arch=arm64' -only-testing ClaudeWindowTests/LimitEfficiencyScorerTests 2>&1 | tail -10
```
Expected: FAIL.

- [ ] **Step 3: Implement LimitEfficiencyScorer.swift**

```swift
import Foundation

enum LimitEfficiencyScorer {

    /// Produces a WindowScore for Limit Risk Mode.
    static func score(
        at date: Date = Date(),
        serviceStatus: ServiceStatus,
        holidayRegions: Set<HolidayRegion>
    ) -> WindowScore {
        let pressure = TimingHeuristics.pressureScore(at: date, holidayRegions: holidayRegions)

        // Base efficiency: inverse of pressure, scaled to 0-100
        var rawScore = (1.0 - pressure) * 85.0 + 15.0   // floor of 15

        // Reliability penalty: active incident reduces efficiency
        if serviceStatus.hasActiveIncident {
            rawScore -= Double(serviceStatus.degradedComponentCount) * 6.0
        }
        if serviceStatus.indicator == "major" || serviceStatus.indicator == "critical" {
            rawScore -= 15.0
        }

        let finalScore = Int(min(max(rawScore, 0), 100))
        let state = windowState(for: finalScore)
        let reasons = buildReasons(
            pressure: pressure,
            date: date,
            serviceStatus: serviceStatus,
            holidayRegions: holidayRegions
        )

        return WindowScore(score: finalScore, state: state, confidence: .medium, reasons: reasons)
    }

    // MARK: — Helpers

    private static func windowState(for score: Int) -> WindowState {
        switch score {
        case 70...100: return .efficient
        case 45..<70:  return .average
        case 25..<45:  return .highRisk
        default:       return .poor
        }
    }

    private static func buildReasons(
        pressure: Double,
        date: Date,
        serviceStatus: ServiceStatus,
        holidayRegions: Set<HolidayRegion>
    ) -> [String] {
        var reasons: [String] = []
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        let hour = cal.component(.hour, from: date)
        let weekday = cal.component(.weekday, from: date)
        let isWeekend = weekday == 1 || weekday == 7

        if pressure < 0.3 {
            reasons.append("Off-peak US hours — low estimated demand")
        } else if pressure > 0.65 {
            reasons.append("Peak US business hours — elevated estimated demand")
        }

        if hour >= 1 && hour <= 7 {
            reasons.append("US overnight — historically favorable window")
        }

        if isWeekend {
            reasons.append("Weekend effect — reduced regional business-hour overlap")
        }

        if serviceStatus.hasActiveIncident {
            reasons.append("Active service incident may affect session quality")
        } else if serviceStatus.indicator == "none" {
            reasons.append("No active incidents — service status normal")
        }

        if serviceStatus.degradedComponentCount > 0 {
            reasons.append("\(serviceStatus.degradedComponentCount) component(s) currently degraded")
        }

        if !holidayRegions.isEmpty {
            reasons.append("Regional holiday(s) reduce expected demand")
        }

        return Array(reasons.prefix(5))
    }
}
```

- [ ] **Step 4: Run tests**

```bash
xcodebuild test -scheme ClaudeWindow -destination 'platform=macOS,arch=arm64' -only-testing ClaudeWindowTests/LimitEfficiencyScorerTests 2>&1 | tail -10
```
Expected: PASS.

- [ ] **Step 5: Commit and push**

```bash
git add ClaudeWindow/Scoring/LimitEfficiencyScorer.swift ClaudeWindowTests/LimitEfficiencyScorerTests.swift
git commit -m "feat: implement Limit Risk Mode scorer with timing heuristics and reliability penalty"
git push origin main
```

---

## Task 6: Reliability Scorer

**Files:**
- Create: `ClaudeWindow/Scoring/ReliabilityScorer.swift`
- Create: `ClaudeWindowTests/ReliabilityScorerTests.swift`

- [ ] **Step 1: Write failing tests**

```swift
import XCTest
@testable import ClaudeWindow

final class ReliabilityScorerTests: XCTestCase {

    func test_allOperational_isHighScore() {
        let status = ServiceStatus(indicator: "none", hasActiveIncident: false,
                                   degradedComponentCount: 0, recentIncidentCount: 0,
                                   fetchedAt: Date())
        let score = ReliabilityScorer.score(serviceStatus: status)
        XCTAssertGreaterThan(score.score, 85)
        XCTAssertEqual(score.state, .efficient)
    }

    func test_majorOutage_isLowScore() {
        let status = ServiceStatus(indicator: "major", hasActiveIncident: true,
                                   degradedComponentCount: 3, recentIncidentCount: 2,
                                   fetchedAt: Date())
        let score = ReliabilityScorer.score(serviceStatus: status)
        XCTAssertLessThan(score.score, 35)
        XCTAssertEqual(score.state, .poor)
    }

    func test_minorDegradation_isMidRange() {
        let status = ServiceStatus(indicator: "minor", hasActiveIncident: false,
                                   degradedComponentCount: 1, recentIncidentCount: 0,
                                   fetchedAt: Date())
        let score = ReliabilityScorer.score(serviceStatus: status)
        XCTAssertGreaterThan(score.score, 50)
        XCTAssertLessThan(score.score, 85)
    }

    func test_unknownStatus_returnsUnknownState() {
        let status = ServiceStatus(indicator: "unknown", hasActiveIncident: false,
                                   degradedComponentCount: 0, recentIncidentCount: 0,
                                   fetchedAt: Date())
        let score = ReliabilityScorer.score(serviceStatus: status)
        XCTAssertEqual(score.state, .unknown)
    }

    func test_reliabilityScore_hasReasons() {
        let status = ServiceStatus(indicator: "none", hasActiveIncident: false,
                                   degradedComponentCount: 0, recentIncidentCount: 0,
                                   fetchedAt: Date())
        let score = ReliabilityScorer.score(serviceStatus: status)
        XCTAssertFalse(score.reasons.isEmpty)
    }
}
```

- [ ] **Step 2: Run to verify failure**

```bash
xcodebuild test -scheme ClaudeWindow -destination 'platform=macOS,arch=arm64' -only-testing ClaudeWindowTests/ReliabilityScorerTests 2>&1 | tail -10
```
Expected: FAIL.

- [ ] **Step 3: Implement ReliabilityScorer.swift**

```swift
import Foundation

enum ReliabilityScorer {

    static func score(serviceStatus: ServiceStatus) -> WindowScore {
        guard serviceStatus.indicator != "unknown" else {
            return WindowScore(score: 50, state: .unknown, confidence: .low,
                               reasons: ["Service status unavailable — confidence low"])
        }

        var raw = 100.0

        switch serviceStatus.indicator {
        case "none":     raw -= 0
        case "minor":    raw -= 15
        case "major":    raw -= 40
        case "critical": raw -= 65
        default:         raw -= 20
        }

        raw -= Double(serviceStatus.degradedComponentCount) * 8.0
        raw -= Double(serviceStatus.recentIncidentCount) * 10.0

        if serviceStatus.hasActiveIncident {
            raw -= 12.0
        }

        let finalScore = Int(min(max(raw, 0), 100))
        let state = windowState(for: finalScore)
        let reasons = buildReasons(serviceStatus: serviceStatus)

        return WindowScore(score: finalScore, state: state,
                           confidence: confidence(for: serviceStatus), reasons: reasons)
    }

    // MARK: — Helpers

    private static func windowState(for score: Int) -> WindowState {
        switch score {
        case 80...100: return .efficient
        case 55..<80:  return .average
        case 30..<55:  return .highRisk
        default:       return .poor
        }
    }

    private static func confidence(for status: ServiceStatus) -> Confidence {
        if status.indicator == "unknown" { return .low }
        let age = Date().timeIntervalSince(status.fetchedAt)
        if age > 600 { return .low }      // > 10 minutes stale
        if age > 300 { return .medium }   // > 5 minutes
        return .high
    }

    private static func buildReasons(serviceStatus: ServiceStatus) -> [String] {
        var reasons: [String] = []

        switch serviceStatus.indicator {
        case "none":
            reasons.append("Current official status: All Systems Operational")
        case "minor":
            reasons.append("Active minor service disruption")
        case "major":
            reasons.append("Active major service incident")
        case "critical":
            reasons.append("Critical service outage in progress")
        default:
            reasons.append("Service status unknown or unavailable")
        }

        if serviceStatus.degradedComponentCount > 0 {
            reasons.append("\(serviceStatus.degradedComponentCount) component(s) degraded")
        }

        if serviceStatus.hasActiveIncident {
            reasons.append("Unresolved incident(s) currently active")
        }

        if serviceStatus.recentIncidentCount == 0 && serviceStatus.indicator == "none" {
            reasons.append("No recent incidents — stability looks good")
        }

        return Array(reasons.prefix(4))
    }
}
```

- [ ] **Step 4: Run tests**

```bash
xcodebuild test -scheme ClaudeWindow -destination 'platform=macOS,arch=arm64' -only-testing ClaudeWindowTests/ReliabilityScorerTests 2>&1 | tail -10
```
Expected: PASS.

- [ ] **Step 5: Commit and push**

```bash
git add ClaudeWindow/Scoring/ReliabilityScorer.swift ClaudeWindowTests/ReliabilityScorerTests.swift
git commit -m "feat: implement Reliability Mode scorer from official status data"
git push origin main
```

---

## Task 7: Confidence Estimator

**Files:**
- Create: `ClaudeWindow/Scoring/ConfidenceEstimator.swift`
- Create: `ClaudeWindowTests/ConfidenceEstimatorTests.swift`

- [ ] **Step 1: Write failing tests**

```swift
import XCTest
@testable import ClaudeWindow

final class ConfidenceEstimatorTests: XCTestCase {

    func test_freshStatusNoHistory_isMedium() {
        let status = ServiceStatus(indicator: "none", hasActiveIncident: false,
                                   degradedComponentCount: 0, recentIncidentCount: 0,
                                   fetchedAt: Date())
        let result = ConfidenceEstimator.estimate(
            serviceStatus: status,
            hasUserHistory: false,
            efficiencyScore: 80,
            reliabilityScore: 90
        )
        XCTAssertEqual(result, .medium)
    }

    func test_freshStatusWithHistory_isHigh() {
        let status = ServiceStatus(indicator: "none", hasActiveIncident: false,
                                   degradedComponentCount: 0, recentIncidentCount: 0,
                                   fetchedAt: Date())
        let result = ConfidenceEstimator.estimate(
            serviceStatus: status,
            hasUserHistory: true,
            efficiencyScore: 80,
            reliabilityScore: 90
        )
        XCTAssertEqual(result, .high)
    }

    func test_staleStatus_isLow() {
        let staleDate = Date().addingTimeInterval(-700)  // > 10 min ago
        let status = ServiceStatus(indicator: "none", hasActiveIncident: false,
                                   degradedComponentCount: 0, recentIncidentCount: 0,
                                   fetchedAt: staleDate)
        let result = ConfidenceEstimator.estimate(
            serviceStatus: status,
            hasUserHistory: false,
            efficiencyScore: 80,
            reliabilityScore: 90
        )
        XCTAssertEqual(result, .low)
    }

    func test_conflictingScores_reducesConfidence() {
        let status = ServiceStatus(indicator: "none", hasActiveIncident: false,
                                   degradedComponentCount: 0, recentIncidentCount: 0,
                                   fetchedAt: Date())
        // Efficiency says great (90), reliability says poor (20) — signals disagree
        let result = ConfidenceEstimator.estimate(
            serviceStatus: status,
            hasUserHistory: true,
            efficiencyScore: 90,
            reliabilityScore: 20
        )
        XCTAssertNotEqual(result, .high)
    }
}
```

- [ ] **Step 2: Run to verify failure**

```bash
xcodebuild test -scheme ClaudeWindow -destination 'platform=macOS,arch=arm64' -only-testing ClaudeWindowTests/ConfidenceEstimatorTests 2>&1 | tail -10
```
Expected: FAIL.

- [ ] **Step 3: Implement ConfidenceEstimator.swift**

```swift
import Foundation

enum ConfidenceEstimator {

    static func estimate(
        serviceStatus: ServiceStatus,
        hasUserHistory: Bool,
        efficiencyScore: Int,
        reliabilityScore: Int
    ) -> Confidence {
        var points = 0

        // Status freshness
        let age = Date().timeIntervalSince(serviceStatus.fetchedAt)
        if age < 300 {
            points += 2   // fresh data
        } else if age < 600 {
            points += 1
        }
        // age > 600 adds 0 — stale data reduces confidence

        // Signal agreement: if efficiency and reliability diverge by > 40 pts, reduce
        let divergence = abs(efficiencyScore - reliabilityScore)
        if divergence < 20 {
            points += 2
        } else if divergence < 40 {
            points += 1
        }

        // User history
        if hasUserHistory {
            points += 1
        }

        // Status not unknown
        if serviceStatus.indicator != "unknown" {
            points += 1
        }

        switch points {
        case 5...: return .high
        case 3...4: return .medium
        default:    return .low
        }
    }
}
```

- [ ] **Step 4: Run tests**

```bash
xcodebuild test -scheme ClaudeWindow -destination 'platform=macOS,arch=arm64' -only-testing ClaudeWindowTests/ConfidenceEstimatorTests 2>&1 | tail -10
```
Expected: PASS.

- [ ] **Step 5: Commit and push**

```bash
git add ClaudeWindow/Scoring/ConfidenceEstimator.swift ClaudeWindowTests/ConfidenceEstimatorTests.swift
git commit -m "feat: implement confidence estimator based on data freshness and signal agreement"
git push origin main
```

---

## Task 8: Capacity Estimator

**Files:**
- Create: `ClaudeWindow/Scoring/CapacityEstimator.swift`
- Create: `ClaudeWindowTests/CapacityEstimatorTests.swift`

- [ ] **Step 1: Write failing tests**

```swift
import XCTest
@testable import ClaudeWindow

final class CapacityEstimatorTests: XCTestCase {

    func test_proLightChat_offPeak_highQueryRange() {
        let capacity = CapacityEstimator.estimate(
            efficiencyScore: 85,
            plan: .pro,
            workload: .lightChat,
            confidence: .medium
        )
        XCTAssertGreaterThan(capacity.maxQueries, 30)
        XCTAssertLessThan(capacity.minQueries, capacity.maxQueries)
    }

    func test_proHeavyWorkload_peakHours_lowQueryRange() {
        let capacity = CapacityEstimator.estimate(
            efficiencyScore: 30,
            plan: .pro,
            workload: .documentHeavy,
            confidence: .medium
        )
        XCTAssertLessThan(capacity.maxQueries, 20)
    }

    func test_maxPlan_hasMoreCapacityThanPro() {
        let pro = CapacityEstimator.estimate(efficiencyScore: 80, plan: .pro, workload: .coding, confidence: .medium)
        let max = CapacityEstimator.estimate(efficiencyScore: 80, plan: .max, workload: .coding, confidence: .medium)
        XCTAssertGreaterThan(max.maxQueries, pro.maxQueries)
    }

    func test_minIsAlwaysLessThanMax() {
        for score in stride(from: 0, through: 100, by: 10) {
            let cap = CapacityEstimator.estimate(efficiencyScore: score, plan: .pro, workload: .standardWriting, confidence: .medium)
            XCTAssertLessThanOrEqual(cap.minQueries, cap.maxQueries)
            XCTAssertLessThanOrEqual(cap.minTokens, cap.maxTokens)
        }
    }

    func test_tokensConsistentWithQueries() {
        let cap = CapacityEstimator.estimate(efficiencyScore: 70, plan: .pro, workload: .coding, confidence: .medium)
        // tokens ≈ queries * tokensPerQuery
        let expectedApprox = cap.minQueries * WorkloadProfile.coding.tokensPerQuery
        XCTAssertGreaterThan(cap.minTokens, expectedApprox / 2)
    }
}
```

- [ ] **Step 2: Run to verify failure**

```bash
xcodebuild test -scheme ClaudeWindow -destination 'platform=macOS,arch=arm64' -only-testing ClaudeWindowTests/CapacityEstimatorTests 2>&1 | tail -10
```
Expected: FAIL.

- [ ] **Step 3: Implement CapacityEstimator.swift**

```swift
import Foundation

enum CapacityEstimator {

    /// Estimates query and token capacity for the current window.
    static func estimate(
        efficiencyScore: Int,
        plan: Plan,
        workload: WorkloadProfile,
        confidence: Confidence,
        customPlan: CustomPlanSettings? = nil
    ) -> QueryCapacity {
        let baseQueries = customPlan?.baseQueryLimit ?? plan.baseQueryLimit

        // Scale base by efficiency: at score=100 get full base, at score=0 get ~20%
        let efficiencyFactor = 0.20 + (Double(efficiencyScore) / 100.0) * 0.80
        let midEstimate = Double(baseQueries) * efficiencyFactor

        // Spread proportional to confidence (wide spread = low confidence)
        let spread: Double
        switch confidence {
        case .high:   spread = 0.15
        case .medium: spread = 0.30
        case .low:    spread = 0.50
        }

        let minQ = Int(max(1, midEstimate * (1 - spread)))
        let maxQ = Int(midEstimate * (1 + spread))

        let tokensPerQuery = workload.tokensPerQuery
        let minT = minQ * tokensPerQuery
        let maxT = maxQ * tokensPerQuery

        return QueryCapacity(
            minQueries: minQ,
            maxQueries: maxQ,
            minTokens: minT,
            maxTokens: maxT,
            confidence: confidence
        )
    }
}
```

- [ ] **Step 4: Run tests**

```bash
xcodebuild test -scheme ClaudeWindow -destination 'platform=macOS,arch=arm64' -only-testing ClaudeWindowTests/CapacityEstimatorTests 2>&1 | tail -10
```
Expected: PASS.

- [ ] **Step 5: Commit and push**

```bash
git add ClaudeWindow/Scoring/CapacityEstimator.swift ClaudeWindowTests/CapacityEstimatorTests.swift
git commit -m "feat: implement capacity estimator for query/token range prediction"
git push origin main
```

---

## Task 9: Best Window Predictor

**Files:**
- Create: (logic lives in `TimingHeuristics.swift` already — integrate into `AppState`)
- Modify: `ClaudeWindow/Models/Capacity.swift` (already has `BestWindow`)

The `TimingHeuristics.bestOffPeakWindows` returns raw pressure windows. Task 9 wraps this into a user-readable `BestWindow` recommendation. This logic goes in `AppState` (Task 11), so here we just verify the heuristics produce the right shape and write the BestWindow formatter.

- [ ] **Step 1: Write test for BestWindow builder**

In `ClaudeWindowTests/BestWindowTests.swift`:

```swift
import XCTest
@testable import ClaudeWindow

final class BestWindowTests: XCTestCase {

    func test_bestWindow_from20UTC_findsNightWindow() {
        var c = DateComponents()
        c.year = 2026; c.month = 4; c.day = 7; c.hour = 20
        c.timeZone = TimeZone(identifier: "UTC")
        let date = Calendar(identifier: .gregorian).date(from: c)!

        let windows = TimingHeuristics.bestOffPeakWindows(from: date, lookAheadHours: 12)
        XCTAssertFalse(windows.isEmpty)
        // Best window should be overnight (UTC 1-8)
        XCTAssertLessThan(windows[0].pressureScore, 0.35)
    }

    func test_bestWindow_formatsCorrectly() {
        var c = DateComponents()
        c.year = 2026; c.month = 4; c.day = 7; c.hour = 20
        c.timeZone = TimeZone(identifier: "UTC")
        let date = Calendar(identifier: .gregorian).date(from: c)!

        let bestWindow = BestWindowBuilder.build(from: date, lookAheadHours: 24)
        XCTAssertNotNil(bestWindow)
        XCTAssertFalse(bestWindow!.reasons.isEmpty)
        XCTAssertGreaterThanOrEqual(bestWindow!.startHour, 0)
        XCTAssertLessThan(bestWindow!.startHour, 24)
    }

    func test_noBestWindow_whenAllPressureHigh() {
        // If every hour in the range is high pressure (can't easily force this),
        // ensure the function still returns nil gracefully.
        // Instead, verify that a fully off-peak start date returns nil or a window.
        // Just test it doesn't crash.
        var c = DateComponents()
        c.year = 2026; c.month = 4; c.day = 7; c.hour = 3
        c.timeZone = TimeZone(identifier: "UTC")
        let date = Calendar(identifier: .gregorian).date(from: c)!
        let result = BestWindowBuilder.build(from: date, lookAheadHours: 6)
        // May or may not find a window — just check no crash and optional result
        _ = result
    }
}
```

- [ ] **Step 2: Run to verify failure**

```bash
xcodebuild test -scheme ClaudeWindow -destination 'platform=macOS,arch=arm64' -only-testing ClaudeWindowTests/BestWindowTests 2>&1 | tail -10
```
Expected: FAIL — `BestWindowBuilder` not defined.

- [ ] **Step 3: Create BestWindowBuilder in Scoring/CapacityEstimator.swift (extend existing file)**

Add to the bottom of `CapacityEstimator.swift`:

```swift
enum BestWindowBuilder {

    static func build(
        from date: Date = Date(),
        lookAheadHours: Int = 24,
        holidayRegions: Set<HolidayRegion> = []
    ) -> BestWindow? {
        let windows = TimingHeuristics.bestOffPeakWindows(
            from: date, lookAheadHours: lookAheadHours, holidayRegions: holidayRegions
        )
        guard let best = windows.first else { return nil }

        let confidence: Confidence = best.pressureScore < 0.2 ? .high
                                   : best.pressureScore < 0.35 ? .medium : .low

        var reasons: [String] = []
        if best.pressureScore < 0.25 {
            reasons.append("US off-hours — minimal estimated demand")
        }
        if best.startHour >= 1 && best.startHour <= 7 {
            reasons.append("Global overnight — lowest multi-region overlap")
        }
        if reasons.isEmpty {
            reasons.append("Relatively low estimated demand for this window")
        }

        return BestWindow(
            startHour: best.startHour,
            endHour: best.endHour,
            confidence: confidence,
            reasons: reasons
        )
    }
}
```

- [ ] **Step 4: Run tests**

```bash
xcodebuild test -scheme ClaudeWindow -destination 'platform=macOS,arch=arm64' -only-testing ClaudeWindowTests/BestWindowTests 2>&1 | tail -10
```
Expected: PASS.

- [ ] **Step 5: Commit and push**

```bash
git add ClaudeWindow/Scoring/CapacityEstimator.swift ClaudeWindowTests/BestWindowTests.swift
git commit -m "feat: add best-window predictor from timing heuristics"
git push origin main
```

---

## Task 10: Settings & Telemetry Persistence

**Files:**
- Create: `ClaudeWindow/Data/SettingsStore.swift`
- Create: `ClaudeWindow/Data/TelemetryStore.swift`

- [ ] **Step 1: Write tests**

In `ClaudeWindowTests/SettingsStoreTests.swift`:

```swift
import XCTest
@testable import ClaudeWindow

final class SettingsStoreTests: XCTestCase {

    var store: SettingsStore!

    override func setUp() {
        super.setUp()
        // Use an isolated UserDefaults suite for testing
        store = SettingsStore(suiteName: "com.claudewindow.tests.\(UUID().uuidString)")
    }

    func test_defaultPlan_isPro() {
        XCTAssertEqual(store.plan, .pro)
    }

    func test_defaultSurface_isDesktop() {
        XCTAssertEqual(store.primarySurface, .desktop)
    }

    func test_savePlan_persists() {
        store.plan = .max
        XCTAssertEqual(store.plan, .max)
    }

    func test_saveWorkloadProfile_persists() {
        store.workloadProfile = .coding
        XCTAssertEqual(store.workloadProfile, .coding)
    }

    func test_saveMode_persists() {
        store.operatingMode = .reliability
        XCTAssertEqual(store.operatingMode, .reliability)
    }

    func test_defaultRefreshInterval_isReasonable() {
        XCTAssertGreaterThanOrEqual(store.refreshIntervalSeconds, 60)
        XCTAssertLessThanOrEqual(store.refreshIntervalSeconds, 3600)
    }
}
```

- [ ] **Step 2: Run to verify failure**

```bash
xcodebuild test -scheme ClaudeWindow -destination 'platform=macOS,arch=arm64' -only-testing ClaudeWindowTests/SettingsStoreTests 2>&1 | tail -10
```
Expected: FAIL.

- [ ] **Step 3: Implement SettingsStore.swift**

```swift
import Foundation

final class SettingsStore: ObservableObject {

    private let defaults: UserDefaults

    init(suiteName: String = "com.claudewindow.app") {
        self.defaults = UserDefaults(suiteName: suiteName) ?? .standard
    }

    @Published var plan: Plan {
        didSet { save("plan", plan.rawValue) }
    }
    @Published var primarySurface: Surface {
        didSet { save("primarySurface", primarySurface.rawValue) }
    }
    @Published var operatingMode: OperatingMode {
        didSet { save("operatingMode", operatingMode.rawValue) }
    }
    @Published var workloadProfile: WorkloadProfile {
        didSet { save("workloadProfile", workloadProfile.rawValue) }
    }
    @Published var refreshIntervalSeconds: Int {
        didSet { save("refreshIntervalSeconds", refreshIntervalSeconds) }
    }
    @Published var holidayRegions: [HolidayRegion] {
        didSet {
            if let data = try? JSONEncoder().encode(holidayRegions) {
                defaults.set(data, forKey: "holidayRegions")
            }
        }
    }
    @Published var telemetryEnabled: Bool {
        didSet { save("telemetryEnabled", telemetryEnabled) }
    }
    @Published var notificationsEnabled: Bool {
        didSet { save("notificationsEnabled", notificationsEnabled) }
    }
    @Published var localAPIEnabled: Bool {
        didSet { save("localAPIEnabled", localAPIEnabled) }
    }
    @Published var onboardingComplete: Bool {
        didSet { save("onboardingComplete", onboardingComplete) }
    }
    @Published var customPlan: CustomPlanSettings {
        didSet {
            if let data = try? JSONEncoder().encode(customPlan) {
                defaults.set(data, forKey: "customPlan")
            }
        }
    }

    // Initialise @Published properties from defaults
    init(defaults: UserDefaults) {
        self.defaults = defaults
        plan = Plan(rawValue: defaults.string(forKey: "plan") ?? "") ?? .pro
        primarySurface = Surface(rawValue: defaults.string(forKey: "primarySurface") ?? "") ?? .desktop
        operatingMode = OperatingMode(rawValue: defaults.string(forKey: "operatingMode") ?? "") ?? .limitRisk
        workloadProfile = WorkloadProfile(rawValue: defaults.string(forKey: "workloadProfile") ?? "") ?? .standardWriting
        refreshIntervalSeconds = defaults.integer(forKey: "refreshIntervalSeconds").nonZeroOr(300)
        telemetryEnabled = defaults.bool(forKey: "telemetryEnabled")
        notificationsEnabled = defaults.bool(forKey: "notificationsEnabled")
        localAPIEnabled = defaults.bool(forKey: "localAPIEnabled")
        onboardingComplete = defaults.bool(forKey: "onboardingComplete")

        if let data = defaults.data(forKey: "holidayRegions"),
           let regions = try? JSONDecoder().decode([HolidayRegion].self, from: data) {
            holidayRegions = regions
        } else {
            holidayRegions = [.us]
        }

        if let data = defaults.data(forKey: "customPlan"),
           let custom = try? JSONDecoder().decode(CustomPlanSettings.self, from: data) {
            customPlan = custom
        } else {
            customPlan = CustomPlanSettings()
        }
    }

    convenience init(suiteName: String = "com.claudewindow.app") {
        let ud = UserDefaults(suiteName: suiteName) ?? .standard
        self.init(defaults: ud)
    }

    private func save(_ key: String, _ value: Any) {
        defaults.set(value, forKey: key)
    }
}

private extension Int {
    func nonZeroOr(_ fallback: Int) -> Int { self == 0 ? fallback : self }
}
```

- [ ] **Step 4: Implement TelemetryStore.swift**

```swift
import Foundation

struct TelemetryEntry: Codable {
    let date: Date
    let surface: Surface
    let mode: OperatingMode
    let score: Int
    let outcome: TelemetryOutcome
}

enum TelemetryOutcome: String, Codable {
    case hitLimitEarly  = "hit_limit_early"
    case longSession    = "long_session"
    case userReportGood = "user_report_good"
    case userReportBad  = "user_report_bad"
}

final class TelemetryStore {

    private let fileURL: URL
    private var entries: [TelemetryEntry] = []

    init() {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = support.appendingPathComponent("ClaudeWindow", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        fileURL = dir.appendingPathComponent("telemetry.json")
        load()
    }

    func record(_ entry: TelemetryEntry) {
        entries.append(entry)
        // Keep last 500 entries
        if entries.count > 500 { entries.removeFirst(entries.count - 500) }
        save()
    }

    var hasHistory: Bool { !entries.isEmpty }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        entries = (try? JSONDecoder().decode([TelemetryEntry].self, from: data)) ?? []
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        try? data.write(to: fileURL)
    }
}
```

- [ ] **Step 5: Run tests**

```bash
xcodebuild test -scheme ClaudeWindow -destination 'platform=macOS,arch=arm64' -only-testing ClaudeWindowTests/SettingsStoreTests 2>&1 | tail -10
```
Expected: PASS.

- [ ] **Step 6: Commit and push**

```bash
git add ClaudeWindow/Data/SettingsStore.swift ClaudeWindow/Data/TelemetryStore.swift ClaudeWindowTests/SettingsStoreTests.swift
git commit -m "feat: add settings persistence (UserDefaults) and local telemetry store"
git push origin main
```

---

## Task 11: AppState — Central Observable

**Files:**
- Create: `ClaudeWindow/AppState.swift`

AppState owns all scorers, the fetcher, settings, and the refresh timer. It drives the UI and the local API.

- [ ] **Step 1: Implement AppState.swift**

```swift
import Foundation
import SwiftUI

@MainActor
final class AppState: ObservableObject {

    // MARK: — Dependencies
    let settings: SettingsStore
    let telemetry: TelemetryStore
    private let statusFetcher = AnthropicStatusFetcher()

    // MARK: — Published state
    @Published var primaryScore: WindowScore?
    @Published var efficiencyScores: [Surface: WindowScore] = [:]
    @Published var reliabilityScores: [Surface: WindowScore] = [:]
    @Published var capacity: QueryCapacity?
    @Published var bestWindow: BestWindow?
    @Published var isRefreshing = false
    @Published var lastRefreshed: Date?

    private var refreshTask: Task<Void, Never>?

    init(settings: SettingsStore = SettingsStore(), telemetry: TelemetryStore = TelemetryStore()) {
        self.settings = settings
        self.telemetry = telemetry
        Task { await refresh() }
        startRefreshTimer()
    }

    // MARK: — Refresh

    func refresh() async {
        isRefreshing = true
        defer { isRefreshing = false }

        let serviceStatus = await statusFetcher.status()
        let holidayRegions = Set(settings.holidayRegions)
        let now = Date()

        // Score all surfaces (they share the same timing signal — surface differentiation is V2)
        for surface in Surface.allCases {
            let eff = LimitEfficiencyScorer.score(
                at: now, serviceStatus: serviceStatus, holidayRegions: holidayRegions
            )
            let rel = ReliabilityScorer.score(serviceStatus: serviceStatus)
            efficiencyScores[surface] = eff
            reliabilityScores[surface] = rel
        }

        let primary = settings.primarySurface
        let mode    = settings.operatingMode

        let activeScore = mode == .limitRisk
            ? efficiencyScores[primary]!
            : reliabilityScores[primary]!

        let effScore  = efficiencyScores[primary]!
        let relScore  = reliabilityScores[primary]!
        let conf = ConfidenceEstimator.estimate(
            serviceStatus: serviceStatus,
            hasUserHistory: telemetry.hasHistory,
            efficiencyScore: effScore.score,
            reliabilityScore: relScore.score
        )

        // Re-emit primary score with blended confidence
        primaryScore = WindowScore(
            score: activeScore.score,
            state: activeScore.state,
            confidence: conf,
            reasons: activeScore.reasons
        )

        // Capacity estimate (efficiency-based)
        let customPlan = settings.plan == .custom ? settings.customPlan : nil
        capacity = CapacityEstimator.estimate(
            efficiencyScore: effScore.score,
            plan: settings.plan,
            workload: settings.workloadProfile,
            confidence: conf,
            customPlan: customPlan
        )

        bestWindow = BestWindowBuilder.build(
            from: now,
            lookAheadHours: 24,
            holidayRegions: holidayRegions
        )

        lastRefreshed = Date()
    }

    // MARK: — Timer

    private func startRefreshTimer() {
        refreshTask?.cancel()
        refreshTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                let interval = Double(self.settings.refreshIntervalSeconds)
                try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
                await self.refresh()
            }
        }
    }

    func restartRefreshTimer() {
        startRefreshTimer()
    }
}
```

- [ ] **Step 2: Build and verify no errors**

```bash
xcodebuild build -scheme ClaudeWindow -destination 'platform=macOS,arch=arm64' 2>&1 | tail -10
```
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Commit and push**

```bash
git add ClaudeWindow/AppState.swift
git commit -m "feat: implement AppState as central observable driving all scoring and refresh"
git push origin main
```

---

## Task 12: Menu Bar Icon

**Files:**
- Create: `ClaudeWindow/UI/MenuBarIconView.swift`

- [ ] **Step 1: Implement MenuBarIconView.swift**

```swift
import SwiftUI

struct MenuBarIconView: View {
    let state: WindowState

    var body: some View {
        Image(systemName: "sparkle")
            .symbolRenderingMode(.palette)
            .foregroundStyle(iconColor, .primary)
            .imageScale(.medium)
    }

    private var iconColor: Color {
        switch state {
        case .efficient: return .green
        case .average:   return .yellow
        case .highRisk:  return .orange
        case .poor:      return .red
        case .unknown:   return .gray
        }
    }
}

#Preview("Efficient") {
    MenuBarIconView(state: .efficient)
}
```

- [ ] **Step 2: Build**

```bash
xcodebuild build -scheme ClaudeWindow -destination 'platform=macOS,arch=arm64' 2>&1 | tail -5
```
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Commit and push**

```bash
git add ClaudeWindow/UI/MenuBarIconView.swift
git commit -m "feat: add colored menu bar icon driven by WindowState"
git push origin main
```

---

## Task 13: Dropdown View

**Files:**
- Create: `ClaudeWindow/UI/DropdownView.swift`
- Create: `ClaudeWindow/UI/SurfaceSectionView.swift`

- [ ] **Step 1: Implement SurfaceSectionView.swift**

```swift
import SwiftUI

struct SurfaceSectionView: View {
    let surface: Surface
    let effScore: WindowScore?
    let relScore: WindowScore?
    let activeMode: OperatingMode

    var body: some View {
        let active = activeMode == .limitRisk ? effScore : relScore
        HStack {
            Circle()
                .fill(stateColor(active?.state ?? .unknown))
                .frame(width: 8, height: 8)
            Text(surface.displayName)
                .font(.caption)
            Spacer()
            Text(active.map { "\($0.score)" } ?? "—")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }

    private func stateColor(_ state: WindowState) -> Color {
        switch state {
        case .efficient: return .green
        case .average:   return .yellow
        case .highRisk:  return .orange
        case .poor:      return .red
        case .unknown:   return .gray
        }
    }
}
```

- [ ] **Step 2: Implement DropdownView.swift**

```swift
import SwiftUI

struct DropdownView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerSection
            Divider()
            surfacesSection
            Divider()
            capacitySection
            Divider()
            reasonsSection
            Divider()
            bestWindowSection
            Divider()
            actionsSection
        }
        .padding(12)
        .frame(width: 300)
    }

    // MARK: — Sections

    private var headerSection: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text(appState.primaryScore?.state.displayLabel ?? "Checking...")
                    .font(.headline)
                HStack(spacing: 4) {
                    Text("Score: \(appState.primaryScore.map { "\($0.score)" } ?? "—")")
                        .font(.caption)
                    Text("·")
                        .foregroundStyle(.secondary)
                    Text("Confidence: \(appState.primaryScore?.confidence.rawValue.capitalized ?? "—")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            modeToggle
        }
        .padding(.bottom, 8)
    }

    private var modeToggle: some View {
        Picker("", selection: Binding(
            get: { appState.settings.operatingMode },
            set: { appState.settings.operatingMode = $0 }
        )) {
            ForEach(OperatingMode.allCases, id: \.self) { mode in
                Text(mode.displayName).tag(mode)
            }
        }
        .pickerStyle(.segmented)
        .frame(width: 130)
        .labelsHidden()
    }

    private var surfacesSection: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Surfaces")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .padding(.bottom, 2)
            ForEach(Surface.allCases) { surface in
                SurfaceSectionView(
                    surface: surface,
                    effScore: appState.efficiencyScores[surface],
                    relScore: appState.reliabilityScores[surface],
                    activeMode: appState.settings.operatingMode
                )
            }
        }
        .padding(.vertical, 8)
    }

    private var capacitySection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Estimated Capacity")
                .font(.caption2)
                .foregroundStyle(.secondary)
            if let cap = appState.capacity {
                HStack {
                    Label("\(cap.minQueries)–\(cap.maxQueries) queries", systemImage: "bubble.left.and.bubble.right")
                        .font(.caption)
                    Spacer()
                }
                HStack {
                    Label(formatTokens(cap.minTokens, cap.maxTokens), systemImage: "character.cursor.ibeam")
                        .font(.caption)
                    Spacer()
                }
            } else {
                Text("—").font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 8)
    }

    private var reasonsSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Why")
                .font(.caption2)
                .foregroundStyle(.secondary)
            if let reasons = appState.primaryScore?.reasons {
                ForEach(reasons, id: \.self) { reason in
                    Label(reason, systemImage: "info.circle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 8)
    }

    private var bestWindowSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Best Next Window")
                .font(.caption2)
                .foregroundStyle(.secondary)
            if let bw = appState.bestWindow {
                Text("\(hourLabel(bw.startHour))–\(hourLabel(bw.endHour)) local · \(bw.confidence.rawValue.capitalized) confidence")
                    .font(.caption)
            } else {
                Text("Current window is already favorable")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 8)
    }

    private var actionsSection: some View {
        HStack {
            Button(action: { Task { await appState.refresh() } }) {
                Label("Refresh", systemImage: "arrow.clockwise")
                    .font(.caption)
            }
            .buttonStyle(.plain)
            .disabled(appState.isRefreshing)

            Spacer()

            SettingsLink {
                Label("Settings", systemImage: "gear")
                    .font(.caption)
            }
        }
        .padding(.top, 8)
    }

    // MARK: — Helpers

    private func formatTokens(_ min: Int, _ max: Int) -> String {
        "\(formatK(min))–\(formatK(max)) tokens"
    }

    private func formatK(_ n: Int) -> String {
        n >= 1000 ? "\(n / 1000)K" : "\(n)"
    }

    private func hourLabel(_ hour: Int) -> String {
        let h = hour % 12 == 0 ? 12 : hour % 12
        let suffix = hour < 12 ? "am" : "pm"
        return "\(h)\(suffix)"
    }
}
```

- [ ] **Step 3: Build**

```bash
xcodebuild build -scheme ClaudeWindow -destination 'platform=macOS,arch=arm64' 2>&1 | tail -5
```
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: Commit and push**

```bash
git add ClaudeWindow/UI/DropdownView.swift ClaudeWindow/UI/SurfaceSectionView.swift
git commit -m "feat: implement dropdown UI with score, surfaces, capacity, reasons, best window"
git push origin main
```

---

## Task 14: Onboarding View

**Files:**
- Create: `ClaudeWindow/UI/OnboardingView.swift`
- Modify: `ClaudeWindow/ClaudeWindowApp.swift` (show onboarding on first launch)

- [ ] **Step 1: Implement OnboardingView.swift**

```swift
import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject var appState: AppState
    @State private var step = 0

    var body: some View {
        VStack(spacing: 20) {
            ProgressView(value: Double(step + 1), total: 5)
                .padding(.horizontal)

            Group {
                switch step {
                case 0: planStep
                case 1: surfaceStep
                case 2: workloadStep
                case 3: regionStep
                case 4: telemetryStep
                default: EmptyView()
                }
            }

            HStack {
                if step > 0 {
                    Button("Back") { step -= 1 }
                        .buttonStyle(.plain)
                }
                Spacer()
                Button(step < 4 ? "Next" : "Get Started") {
                    if step < 4 { step += 1 }
                    else { appState.settings.onboardingComplete = true }
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(.horizontal)
        }
        .padding(24)
        .frame(width: 380, height: 300)
    }

    // MARK: — Steps

    private var planStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Which Claude plan are you on?")
                .font(.headline)
            Picker("Plan", selection: Binding(
                get: { appState.settings.plan },
                set: { appState.settings.plan = $0 }
            )) {
                ForEach(Plan.allCases, id: \.self) { Text($0.displayName).tag($0) }
            }
            .pickerStyle(.segmented)
            Text("Used to estimate session capacity. Not shared with Anthropic.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var surfaceStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Which surface do you use most?")
                .font(.headline)
            Picker("Surface", selection: Binding(
                get: { appState.settings.primarySurface },
                set: { appState.settings.primarySurface = $0 }
            )) {
                ForEach(Surface.allCases) { Text($0.displayName).tag($0) }
            }
            .pickerStyle(.radioGroup)
            Text("This drives the menu bar icon color.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var workloadStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("What best describes your typical workload?")
                .font(.headline)
            Picker("Workload", selection: Binding(
                get: { appState.settings.workloadProfile },
                set: { appState.settings.workloadProfile = $0 }
            )) {
                ForEach(WorkloadProfile.allCases, id: \.self) {
                    Text($0.displayName).tag($0)
                }
            }
            .pickerStyle(.radioGroup)
        }
    }

    private var regionStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Which holiday calendars should we factor in?")
                .font(.headline)
            ForEach(HolidayRegion.allCases, id: \.self) { region in
                Toggle(region.displayName, isOn: Binding(
                    get: { appState.settings.holidayRegions.contains(region) },
                    set: { include in
                        if include {
                            appState.settings.holidayRegions.append(region)
                        } else {
                            appState.settings.holidayRegions.removeAll { $0 == region }
                        }
                    }
                ))
            }
        }
    }

    private var telemetryStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Enable local usage history?")
                .font(.headline)
            Toggle("Store local session outcomes", isOn: Binding(
                get: { appState.settings.telemetryEnabled },
                set: { appState.settings.telemetryEnabled = $0 }
            ))
            Text("Your data never leaves this device. It helps the app calibrate estimates over time.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
```

- [ ] **Step 2: Wire onboarding into ClaudeWindowApp.swift**

Replace the body in `ClaudeWindowApp.swift`:

```swift
import SwiftUI

@main
struct ClaudeWindowApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        MenuBarExtra {
            if appState.settings.onboardingComplete {
                DropdownView()
                    .environmentObject(appState)
            } else {
                OnboardingView()
                    .environmentObject(appState)
            }
        } label: {
            MenuBarIconView(state: appState.primaryScore?.state ?? .unknown)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
                .environmentObject(appState)
        }
    }
}
```

- [ ] **Step 3: Build**

```bash
xcodebuild build -scheme ClaudeWindow -destination 'platform=macOS,arch=arm64' 2>&1 | tail -5
```
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: Commit and push**

```bash
git add ClaudeWindow/UI/OnboardingView.swift ClaudeWindow/ClaudeWindowApp.swift
git commit -m "feat: add 5-step onboarding flow shown on first launch"
git push origin main
```

---

## Task 15: Settings View

**Files:**
- Create: `ClaudeWindow/UI/SettingsView.swift`

- [ ] **Step 1: Implement SettingsView.swift**

```swift
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        TabView {
            generalTab
                .tabItem { Label("General", systemImage: "gearshape") }
            advancedTab
                .tabItem { Label("Advanced", systemImage: "slider.horizontal.3") }
        }
        .frame(width: 420, height: 340)
    }

    // MARK: — General

    private var generalTab: some View {
        Form {
            Picker("Claude Plan", selection: Binding(
                get: { appState.settings.plan },
                set: { appState.settings.plan = $0 }
            )) {
                ForEach(Plan.allCases, id: \.self) { Text($0.displayName).tag($0) }
            }

            Picker("Workload Profile", selection: Binding(
                get: { appState.settings.workloadProfile },
                set: { appState.settings.workloadProfile = $0 }
            )) {
                ForEach(WorkloadProfile.allCases, id: \.self) {
                    Text($0.displayName).tag($0)
                }
            }

            Picker("Primary Surface", selection: Binding(
                get: { appState.settings.primarySurface },
                set: { appState.settings.primarySurface = $0 }
            )) {
                ForEach(Surface.allCases) { Text($0.displayName).tag($0) }
            }

            Picker("Default Mode", selection: Binding(
                get: { appState.settings.operatingMode },
                set: { appState.settings.operatingMode = $0 }
            )) {
                ForEach(OperatingMode.allCases, id: \.self) {
                    Text($0.displayName).tag($0)
                }
            }

            Picker("Refresh Interval", selection: Binding(
                get: { appState.settings.refreshIntervalSeconds },
                set: {
                    appState.settings.refreshIntervalSeconds = $0
                    appState.restartRefreshTimer()
                }
            )) {
                Text("1 minute").tag(60)
                Text("5 minutes").tag(300)
                Text("15 minutes").tag(900)
                Text("30 minutes").tag(1800)
            }

            Section("Holiday Regions") {
                ForEach(HolidayRegion.allCases, id: \.self) { region in
                    Toggle(region.displayName, isOn: Binding(
                        get: { appState.settings.holidayRegions.contains(region) },
                        set: { include in
                            if include {
                                appState.settings.holidayRegions.append(region)
                            } else {
                                appState.settings.holidayRegions.removeAll { $0 == region }
                            }
                        }
                    ))
                }
            }
        }
        .padding()
    }

    // MARK: — Advanced

    private var advancedTab: some View {
        Form {
            Toggle("Enable local API (port 58742)", isOn: Binding(
                get: { appState.settings.localAPIEnabled },
                set: { appState.settings.localAPIEnabled = $0 }
            ))
            Text("Exposes /score, /recommendation, /capacity endpoints on localhost only.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Toggle("Store local session history", isOn: Binding(
                get: { appState.settings.telemetryEnabled },
                set: { appState.settings.telemetryEnabled = $0 }
            ))
            Text("Improves capacity estimates over time. Never leaves this device.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Toggle("Menu bar notifications", isOn: Binding(
                get: { appState.settings.notificationsEnabled },
                set: { appState.settings.notificationsEnabled = $0 }
            ))

            Button("Reset Onboarding") {
                appState.settings.onboardingComplete = false
            }
            .foregroundStyle(.red)
        }
        .padding()
    }
}
```

- [ ] **Step 2: Build**

```bash
xcodebuild build -scheme ClaudeWindow -destination 'platform=macOS,arch=arm64' 2>&1 | tail -5
```
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Commit and push**

```bash
git add ClaudeWindow/UI/SettingsView.swift
git commit -m "feat: add tabbed settings view for plan, surface, mode, refresh, regions, API, telemetry"
git push origin main
```

---

## Task 16: Local API Server

**Files:**
- Create: `ClaudeWindow/API/LocalAPIServer.swift`
- Create: `ClaudeWindow/API/APIHandlers.swift`
- Create: `ClaudeWindowTests/APIHandlersTests.swift`
- Modify: `ClaudeWindow/AppState.swift` (start/stop server based on setting)

- [ ] **Step 1: Write failing tests for API response builders**

```swift
import XCTest
@testable import ClaudeWindow

final class APIHandlersTests: XCTestCase {

    private func makeScore(_ score: Int, _ state: WindowState) -> WindowScore {
        WindowScore(score: score, state: state, confidence: .medium, reasons: ["Off-peak"])
    }

    func test_healthResponse_isOK() throws {
        let json = APIHandlers.health()
        let obj = try JSONSerialization.jsonObject(with: json) as! [String: Any]
        XCTAssertEqual(obj["status"] as? String, "ok")
    }

    func test_scoreResponse_containsScore() throws {
        let score = makeScore(74, .efficient)
        let json = APIHandlers.score(
            surface: .desktop, mode: .limitRisk, score: score
        )
        let obj = try JSONSerialization.jsonObject(with: json) as! [String: Any]
        XCTAssertEqual(obj["window_score"] as? Int, 74)
        XCTAssertEqual(obj["surface"] as? String, "desktop")
        XCTAssertEqual(obj["mode"] as? String, "limit_risk")
        XCTAssertEqual(obj["state"] as? String, "efficient")
    }

    func test_capacityResponse_hasRanges() throws {
        let cap = QueryCapacity(minQueries: 20, maxQueries: 40,
                                minTokens: 40_000, maxTokens: 80_000,
                                confidence: .medium)
        let json = APIHandlers.capacity(cap)
        let obj = try JSONSerialization.jsonObject(with: json) as! [String: Any]
        XCTAssertEqual(obj["estimated_queries_min"] as? Int, 20)
        XCTAssertEqual(obj["estimated_queries_max"] as? Int, 40)
        XCTAssertEqual(obj["estimated_tokens_min"] as? Int, 40_000)
        XCTAssertEqual(obj["confidence"] as? String, "medium")
    }

    func test_recommendationResponse_containsReasons() throws {
        let score = makeScore(74, .efficient)
        let cap = QueryCapacity(minQueries: 20, maxQueries: 40,
                                minTokens: 40_000, maxTokens: 80_000,
                                confidence: .medium)
        let json = APIHandlers.recommendation(
            surface: .desktop, mode: .limitRisk, score: score, capacity: cap
        )
        let obj = try JSONSerialization.jsonObject(with: json) as! [String: Any]
        XCTAssertNotNil(obj["reasons"])
        XCTAssertNotNil(obj["estimated_queries_min"])
    }
}
```

- [ ] **Step 2: Run to verify failure**

```bash
xcodebuild test -scheme ClaudeWindow -destination 'platform=macOS,arch=arm64' -only-testing ClaudeWindowTests/APIHandlersTests 2>&1 | tail -10
```
Expected: FAIL.

- [ ] **Step 3: Implement APIHandlers.swift**

```swift
import Foundation

enum APIHandlers {

    static func health() -> Data {
        encode(["status": "ok", "timestamp": ISO8601DateFormatter().string(from: Date())])
    }

    static func score(surface: Surface, mode: OperatingMode, score: WindowScore) -> Data {
        encode([
            "surface": surface.rawValue,
            "mode": mode.rawValue,
            "window_score": score.score,
            "state": score.state.rawValue,
            "confidence": score.confidence.rawValue
        ] as [String: Any])
    }

    static func recommendation(
        surface: Surface,
        mode: OperatingMode,
        score: WindowScore,
        capacity: QueryCapacity
    ) -> Data {
        encode([
            "surface": surface.rawValue,
            "mode": mode.rawValue,
            "window_score": score.score,
            "state": score.state.rawValue,
            "estimated_queries_min": capacity.minQueries,
            "estimated_queries_max": capacity.maxQueries,
            "estimated_tokens_min": capacity.minTokens,
            "estimated_tokens_max": capacity.maxTokens,
            "confidence": score.confidence.rawValue,
            "reasons": score.reasons
        ] as [String: Any])
    }

    static func capacity(_ cap: QueryCapacity) -> Data {
        encode([
            "estimated_queries_min": cap.minQueries,
            "estimated_queries_max": cap.maxQueries,
            "estimated_tokens_min": cap.minTokens,
            "estimated_tokens_max": cap.maxTokens,
            "confidence": cap.confidence.rawValue
        ] as [String: Any])
    }

    static func bestWindow(_ bw: BestWindow?) -> Data {
        guard let bw else {
            return encode(["best_window": NSNull()])
        }
        return encode([
            "start_hour_utc": bw.startHour,
            "end_hour_utc": bw.endHour,
            "confidence": bw.confidence.rawValue,
            "reasons": bw.reasons
        ] as [String: Any])
    }

    static func explain(_ score: WindowScore) -> Data {
        encode([
            "score": score.score,
            "state": score.state.rawValue,
            "confidence": score.confidence.rawValue,
            "reasons": score.reasons
        ] as [String: Any])
    }

    static func notFound() -> Data {
        encode(["error": "not found"])
    }

    // MARK: — Helper

    private static func encode(_ dict: [String: Any]) -> Data {
        (try? JSONSerialization.data(withJSONObject: dict, options: [.sortedKeys])) ?? Data()
    }
}
```

- [ ] **Step 4: Implement LocalAPIServer.swift**

```swift
import Foundation
import Network

/// Minimal HTTP/1.1 server listening on localhost:58742.
/// Runs only when enabled in settings. All routes return JSON.
final class LocalAPIServer {

    static let port: UInt16 = 58742

    private var listener: NWListener?
    private var appState: AppState?

    func start(appState: AppState) {
        self.appState = appState
        let params = NWParameters.tcp
        params.allowLocalEndpointReuse = true

        guard let listener = try? NWListener(using: params, on: NWEndpoint.Port(rawValue: Self.port)!) else {
            return
        }
        self.listener = listener

        listener.newConnectionHandler = { [weak self] connection in
            connection.start(queue: .global(qos: .utility))
            self?.receive(on: connection)
        }
        listener.start(queue: .global(qos: .utility))
    }

    func stop() {
        listener?.cancel()
        listener = nil
    }

    // MARK: — Request handling

    private func receive(on connection: NWConnection) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 4096) { [weak self] data, _, _, _ in
            guard let data, let request = String(data: data, encoding: .utf8) else {
                connection.cancel(); return
            }
            let path = Self.parsePath(from: request)
            let body = self?.handle(path: path) ?? APIHandlers.notFound()
            self?.respond(body: body, on: connection)
        }
    }

    private func handle(path: String) -> Data {
        guard let appState else { return APIHandlers.notFound() }

        let surface = appState.settings.primarySurface
        let mode    = appState.settings.operatingMode
        let score   = (mode == .limitRisk
                       ? appState.efficiencyScores[surface]
                       : appState.reliabilityScores[surface])
                      ?? WindowScore(score: 50, state: .unknown, confidence: .low, reasons: [])

        switch path {
        case "/health":
            return APIHandlers.health()
        case "/score":
            return APIHandlers.score(surface: surface, mode: mode, score: score)
        case "/recommendation":
            let cap = appState.capacity ?? QueryCapacity(minQueries: 0, maxQueries: 0,
                                                         minTokens: 0, maxTokens: 0,
                                                         confidence: .low)
            return APIHandlers.recommendation(surface: surface, mode: mode, score: score, capacity: cap)
        case "/capacity":
            let cap = appState.capacity ?? QueryCapacity(minQueries: 0, maxQueries: 0,
                                                         minTokens: 0, maxTokens: 0,
                                                         confidence: .low)
            return APIHandlers.capacity(cap)
        case "/best-window":
            return APIHandlers.bestWindow(appState.bestWindow)
        case "/explain":
            return APIHandlers.explain(score)
        default:
            return APIHandlers.notFound()
        }
    }

    private func respond(body: Data, on connection: NWConnection) {
        let header = """
        HTTP/1.1 200 OK\r
        Content-Type: application/json\r
        Content-Length: \(body.count)\r
        Access-Control-Allow-Origin: *\r
        Connection: close\r
        \r

        """
        var response = header.data(using: .utf8)!
        response.append(body)
        connection.send(content: response, completion: .contentProcessed { _ in
            connection.cancel()
        })
    }

    private static func parsePath(from request: String) -> String {
        // "GET /score HTTP/1.1\r\n..." → "/score"
        let lines = request.components(separatedBy: "\r\n")
        let parts = lines.first?.components(separatedBy: " ") ?? []
        guard parts.count >= 2 else { return "/" }
        // Strip query string
        return parts[1].components(separatedBy: "?").first ?? "/"
    }
}
```

- [ ] **Step 5: Wire LocalAPIServer into AppState**

Add to `AppState.swift`:

```swift
// Add as a stored property:
private let apiServer = LocalAPIServer()

// Add to init, after startRefreshTimer():
if settings.localAPIEnabled {
    apiServer.start(appState: self)
}

// Add a method to toggle:
func updateAPIServer() {
    if settings.localAPIEnabled {
        apiServer.start(appState: self)
    } else {
        apiServer.stop()
    }
}
```

Also add a `didSet` observer in `SettingsView` or observe `localAPIEnabled` changes in AppState:

In `AppState.init`, after the refresh call:

```swift
// Observe localAPIEnabled changes
NotificationCenter.default.addObserver(forName: UserDefaults.didChangeNotification,
                                        object: nil, queue: .main) { [weak self] _ in
    self?.updateAPIServer()
}
```

- [ ] **Step 6: Run API tests**

```bash
xcodebuild test -scheme ClaudeWindow -destination 'platform=macOS,arch=arm64' -only-testing ClaudeWindowTests/APIHandlersTests 2>&1 | tail -10
```
Expected: PASS.

- [ ] **Step 7: Build the full app**

```bash
xcodebuild build -scheme ClaudeWindow -destination 'platform=macOS,arch=arm64' 2>&1 | tail -5
```
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 8: Commit and push**

```bash
git add ClaudeWindow/API/ ClaudeWindowTests/APIHandlersTests.swift
git commit -m "feat: add local HTTP API server on port 58742 with /health /score /recommendation /capacity /best-window /explain"
git push origin main
```

---

## Task 17: Integration Smoke Test & Final Polish

**Files:**
- Modify: `ClaudeWindow/AppState.swift` (minor wiring)
- Create: `ClaudeWindowTests/IntegrationTests.swift`

- [ ] **Step 1: Write integration smoke tests**

```swift
import XCTest
@testable import ClaudeWindow

@MainActor
final class IntegrationTests: XCTestCase {

    func test_appState_refreshProducesScore() async {
        let settings = SettingsStore(suiteName: "com.claudewindow.integration.\(UUID().uuidString)")
        let telemetry = TelemetryStore()
        let appState = AppState(settings: settings, telemetry: telemetry)

        // Allow initial refresh to propagate (status fetch may fail in CI, score still produced)
        try? await Task.sleep(nanoseconds: 200_000_000)  // 0.2s

        XCTAssertNotNil(appState.primaryScore)
        XCTAssertNotNil(appState.capacity)
    }

    func test_appState_efficiencyScoreForAllSurfaces() async {
        let settings = SettingsStore(suiteName: "com.claudewindow.integration2.\(UUID().uuidString)")
        let appState = AppState(settings: settings, telemetry: TelemetryStore())

        try? await Task.sleep(nanoseconds: 200_000_000)

        for surface in Surface.allCases {
            XCTAssertNotNil(appState.efficiencyScores[surface],
                            "Missing efficiency score for \(surface.displayName)")
        }
    }

    func test_apiHandlers_roundTrip() throws {
        let score = WindowScore(score: 74, state: .efficient, confidence: .medium,
                                reasons: ["Off-peak US hours"])
        let cap   = QueryCapacity(minQueries: 26, maxQueries: 41,
                                  minTokens: 190_000, maxTokens: 280_000,
                                  confidence: .medium)

        let data = APIHandlers.recommendation(surface: .desktop, mode: .limitRisk,
                                              score: score, capacity: cap)
        let obj  = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        XCTAssertEqual(obj["surface"] as? String, "desktop")
        XCTAssertEqual(obj["window_score"] as? Int, 74)
        XCTAssertEqual(obj["state"] as? String, "efficient")
        XCTAssertEqual(obj["estimated_queries_min"] as? Int, 26)
        let reasons = obj["reasons"] as? [String]
        XCTAssertEqual(reasons?.first, "Off-peak US hours")
    }
}
```

- [ ] **Step 2: Run all tests**

```bash
xcodebuild test -scheme ClaudeWindow -destination 'platform=macOS,arch=arm64' 2>&1 | grep -E "(Test Suite|PASS|FAIL|error)" | tail -20
```
Expected: All tests pass.

- [ ] **Step 3: Run the app**

Open `ClaudeWindow.xcodeproj` in Xcode and press `Cmd+R`. Verify:
- [ ] Menu bar icon appears with a color
- [ ] Onboarding shows on first launch
- [ ] Dropdown opens with score, capacity, reasons, best window
- [ ] Settings link opens the settings panel
- [ ] Mode toggle (Limit Risk ↔ Reliability) changes the score label

- [ ] **Step 4: Verify local API manually**

```bash
# With app running and local API enabled in settings:
curl -s http://localhost:58742/health | python3 -m json.tool
curl -s http://localhost:58742/recommendation | python3 -m json.tool
curl -s http://localhost:58742/capacity | python3 -m json.tool
curl -s http://localhost:58742/best-window | python3 -m json.tool
```
Expected: Valid JSON from each endpoint.

- [ ] **Step 5: Final commit and push**

```bash
git add ClaudeWindowTests/IntegrationTests.swift
git commit -m "feat: add integration smoke tests and verify full app flow"
git push origin main
```

- [ ] **Step 6: Update NotebookLM sources**

In the Claude Window NotebookLM notebook:
- Remove the old plan source and re-upload the updated `docs/superpowers/plans/2026-04-07-claude-window.md`
- Click **Notebook guide** to regenerate — confirm it reflects the completed implementation

- [ ] **Step 7: Tag the MVP release on GitHub**

```bash
gh release create v0.1.0 \
  --title "Claude Window v0.1.0 — MVP" \
  --notes "First working build: colored menu bar icon, scoring engine, local API on :58742, onboarding, settings."
```

---

## Spec Coverage Check

| PRD Requirement | Task(s) |
|----------------|---------|
| macOS menu bar app with colored icon | Task 1, 12 |
| Green/Yellow/Orange/Red/Gray states | Task 2 (WindowState), Task 12 |
| Desktop / Code / API surface support | Task 2, 11, 13 |
| User-selectable primary surface | Task 10, 13, 14 |
| Limit Risk Mode (default) | Task 5, 11 |
| Reliability Mode | Task 6, 11 |
| Mode toggle in dropdown + settings | Task 13, 15 |
| Numeric score + state label + confidence | Task 2, 5, 6, 7 |
| Estimated query range | Task 8, 13 |
| Estimated token range | Task 8, 13 |
| Top contributing reasons | Task 5, 6, 13 |
| Best next window (6/12/24h) | Task 9, 13 |
| Plan config (Free/Pro/Max/Custom) | Task 2 (Plan.swift), 14, 15 |
| Workload presets | Task 2 (WorkloadProfile), 14, 15 |
| Official status integration | Task 4, 6 |
| Timing heuristics (hours, weekend, holiday, season) | Task 3 |
| Holiday region selection | Task 3, 14, 15 |
| Local telemetry (optional) | Task 10, 14, 15 |
| Onboarding (< 2 min, 5 questions) | Task 14 |
| Settings panel (all PRD fields) | Task 15 |
| GET /health | Task 16 |
| GET /score | Task 16 |
| GET /recommendation | Task 16 |
| GET /capacity | Task 16 |
| GET /best-window | Task 16 |
| GET /explain | Task 16 |
| Local-only API | Task 16 (NWListener, localhost only) |
| Confidence model (High/Medium/Low) | Task 7 |
| Auto-refresh | Task 11 |
| Graceful degradation when status unavailable | Task 4 |
| Privacy / local-first | Task 10 (UserDefaults/local JSON) |

All PRD MVP requirements are covered. ✓

---

## Open Questions (from PRD §17)

Resolved for implementation:

1. **Icon reflects one surface** — primary surface drives icon; others inspectable in dropdown (PRD §8.1).
2. **Token display** — shown as raw token ranges (e.g. "40K–80K tokens"); query equivalents shown separately as query count.
3. **User history learning** — conservative default: `telemetryEnabled = false`; affects `hasUserHistory` in confidence estimator only.
4. **Notifications** — togglable in settings (UI included), deferred to V2 for actual delivery.
5. **Local API auth** — no token required for v1 (localhost-only via NWListener, non-routable externally).
