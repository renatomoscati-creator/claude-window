import XCTest
@testable import ClaudeWindow

final class LimitEfficiencyScorerTests: XCTestCase {

    // 07:00 UTC Tuesday = low pressure
    private func lowPressureDate() -> Date {
        var c = DateComponents()
        c.year = 2026; c.month = 4; c.day = 7; c.hour = 7
        c.timeZone = TimeZone(identifier: "UTC")
        return Calendar(identifier: .gregorian).date(from: c)!
    }

    // 20:00 UTC Tuesday = high pressure
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
        let without = LimitEfficiencyScorer.score(
            at: highPressureDate(), serviceStatus: noIncident(), holidayRegions: []
        )
        let with_ = LimitEfficiencyScorer.score(
            at: highPressureDate(), serviceStatus: activeIncident(), holidayRegions: []
        )
        XCTAssertLessThan(with_.score, without.score)
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
