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
        let json = APIHandlers.score(surface: .desktop, mode: .limitRisk, score: score)
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
        let json = APIHandlers.recommendation(surface: .desktop, mode: .limitRisk,
                                              score: score, capacity: cap)
        let obj = try JSONSerialization.jsonObject(with: json) as! [String: Any]
        XCTAssertNotNil(obj["reasons"])
        XCTAssertNotNil(obj["estimated_queries_min"])
    }
}
