import XCTest
@testable import ClaudeWindow

@MainActor
final class IntegrationTests: XCTestCase {

    func test_appState_refreshProducesScore() async {
        let settings = SettingsStore(suiteName: "com.claudewindow.integration.\(UUID().uuidString)")
        let telemetry = TelemetryStore()
        let appState = AppState(settings: settings, telemetry: telemetry)

        // Short wait to allow initial refresh to propagate
        try? await Task.sleep(nanoseconds: 500_000_000)

        XCTAssertNotNil(appState.primaryScore)
        XCTAssertNotNil(appState.capacity)
    }

    func test_appState_efficiencyScoreForAllSurfaces() async {
        let settings = SettingsStore(suiteName: "com.claudewindow.integration2.\(UUID().uuidString)")
        let appState = AppState(settings: settings, telemetry: TelemetryStore())

        try? await Task.sleep(nanoseconds: 500_000_000)

        for surface in Surface.allCases {
            XCTAssertNotNil(appState.efficiencyScores[surface],
                            "Missing efficiency score for \(surface.displayName)")
        }
    }

    func test_apiHandlers_roundTrip() throws {
        let score = WindowScore(score: 74, state: .efficient, confidence: .medium,
                                reasons: ["Off-peak US hours"])
        let cap = QueryCapacity(minQueries: 26, maxQueries: 41,
                                minTokens: 190_000, maxTokens: 280_000,
                                model: .sonnet, confidence: .medium)

        let data = APIHandlers.recommendation(surface: .desktop, mode: .limitRisk,
                                              score: score, capacity: cap)
        let obj = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        XCTAssertEqual(obj["surface"] as? String, "desktop")
        XCTAssertEqual(obj["window_score"] as? Int, 74)
        XCTAssertEqual(obj["state"] as? String, "efficient")
        XCTAssertEqual(obj["estimated_queries_min"] as? Int, 26)
        let reasons = obj["reasons"] as? [String]
        XCTAssertEqual(reasons?.first, "Off-peak US hours")
    }

    func test_scoringPipeline_endToEnd() {
        let status = ServiceStatus(indicator: "none", hasActiveIncident: false,
                                   degradedComponentCount: 0, recentIncidentCount: 0,
                                   fetchedAt: Date())
        let effScore = LimitEfficiencyScorer.score(at: Date(), serviceStatus: status, holidayRegions: [])
        let relScore = ReliabilityScorer.score(serviceStatus: status)
        let conf = ConfidenceEstimator.estimate(
            serviceStatus: status, hasUserHistory: false,
            efficiencyScore: effScore.score, reliabilityScore: relScore.score
        )
        let cap = CapacityEstimator.estimate(
            efficiencyScore: effScore.score, plan: .pro, model: .sonnet,
            workload: .standardWriting, confidence: conf
        )
        XCTAssertGreaterThan(effScore.score, 0)
        XCTAssertGreaterThan(relScore.score, 0)
        XCTAssertGreaterThan(cap.maxQueries, 0)
        XCTAssertFalse(effScore.reasons.isEmpty)
    }
}
