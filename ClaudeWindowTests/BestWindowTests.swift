import XCTest
@testable import ClaudeWindow

final class BestWindowTests: XCTestCase {

    private func date(year: Int, month: Int, day: Int, hour: Int) -> Date {
        var c = DateComponents()
        c.year = year; c.month = month; c.day = day; c.hour = hour; c.minute = 0
        c.timeZone = TimeZone(identifier: "UTC")
        return Calendar(identifier: .gregorian).date(from: c)!
    }

    func test_bestWindow_from20UTC_findsNightWindow() {
        let d = date(year: 2026, month: 4, day: 7, hour: 20)
        let windows = TimingHeuristics.bestOffPeakWindows(from: d, lookAheadHours: 12)
        XCTAssertFalse(windows.isEmpty)
        XCTAssertLessThan(windows[0].pressureScore, 0.35)
    }

    func test_bestWindow_formatsCorrectly() {
        let d = date(year: 2026, month: 4, day: 7, hour: 20)
        let bw = BestWindowBuilder.build(from: d, lookAheadHours: 24)
        XCTAssertNotNil(bw)
        XCTAssertFalse(bw!.reasons.isEmpty)
        XCTAssertGreaterThanOrEqual(bw!.startHour, 0)
        XCTAssertLessThan(bw!.startHour, 24)
    }

    func test_noCrashOnOffPeakStart() {
        let d = date(year: 2026, month: 4, day: 7, hour: 3)
        _ = BestWindowBuilder.build(from: d, lookAheadHours: 6)
    }
}
