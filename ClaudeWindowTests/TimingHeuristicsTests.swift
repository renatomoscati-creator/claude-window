import XCTest
@testable import ClaudeWindow

final class TimingHeuristicsTests: XCTestCase {

    // 2026-04-07 is a Tuesday
    private func tuesdayUTC(_ hour: Int) -> Date {
        var comps = DateComponents()
        comps.year = 2026; comps.month = 4; comps.day = 7
        comps.hour = hour; comps.minute = 0; comps.second = 0
        comps.timeZone = TimeZone(identifier: "UTC")
        return Calendar(identifier: .gregorian).date(from: comps)!
    }

    // 2026-04-11 is a Saturday
    private func saturdayUTC(_ hour: Int) -> Date {
        var comps = DateComponents()
        comps.year = 2026; comps.month = 4; comps.day = 11
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
        XCTAssertLessThan(windows[0].pressureScore, 0.4)
    }

    func test_holidayRegions_USHoliday_reducesUsPressure() {
        // 2025-07-04 = Friday (US Independence Day)
        var comps = DateComponents()
        comps.year = 2025; comps.month = 7; comps.day = 4
        comps.hour = 20; comps.minute = 0
        comps.timeZone = TimeZone(identifier: "UTC")
        let holiday = Calendar(identifier: .gregorian).date(from: comps)!

        let normalScore = TimingHeuristics.pressureScore(at: tuesdayUTC(20), holidayRegions: [])
        let holidayScore = TimingHeuristics.pressureScore(at: holiday, holidayRegions: [.us])
        XCTAssertLessThan(holidayScore, normalScore)
    }
}
