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
