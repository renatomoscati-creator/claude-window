import XCTest
@testable import ClaudeWindow

final class ConfidenceEstimatorTests: XCTestCase {

    func test_freshStatusNoHistory_isMedium() {
        let status = ServiceStatus(indicator: "none", hasActiveIncident: false,
                                   degradedComponentCount: 0, recentIncidentCount: 0,
                                   fetchedAt: Date())
        let result = ConfidenceEstimator.estimate(
            serviceStatus: status, hasUserHistory: false,
            efficiencyScore: 80, reliabilityScore: 90
        )
        XCTAssertEqual(result, .medium)
    }

    func test_freshStatusWithHistory_isHigh() {
        let status = ServiceStatus(indicator: "none", hasActiveIncident: false,
                                   degradedComponentCount: 0, recentIncidentCount: 0,
                                   fetchedAt: Date())
        let result = ConfidenceEstimator.estimate(
            serviceStatus: status, hasUserHistory: true,
            efficiencyScore: 80, reliabilityScore: 90
        )
        XCTAssertEqual(result, .high)
    }

    func test_staleStatus_isLow() {
        let staleDate = Date().addingTimeInterval(-700)
        let status = ServiceStatus(indicator: "none", hasActiveIncident: false,
                                   degradedComponentCount: 0, recentIncidentCount: 0,
                                   fetchedAt: staleDate)
        let result = ConfidenceEstimator.estimate(
            serviceStatus: status, hasUserHistory: false,
            efficiencyScore: 80, reliabilityScore: 90
        )
        XCTAssertEqual(result, .low)
    }

    func test_conflictingScores_reducesConfidence() {
        let status = ServiceStatus(indicator: "none", hasActiveIncident: false,
                                   degradedComponentCount: 0, recentIncidentCount: 0,
                                   fetchedAt: Date())
        let result = ConfidenceEstimator.estimate(
            serviceStatus: status, hasUserHistory: true,
            efficiencyScore: 90, reliabilityScore: 20
        )
        XCTAssertNotEqual(result, .high)
    }
}
