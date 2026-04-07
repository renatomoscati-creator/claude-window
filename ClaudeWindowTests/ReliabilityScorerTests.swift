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
