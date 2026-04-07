import XCTest
@testable import ClaudeWindow

final class ModelsTests: XCTestCase {

    func test_workloadProfile_tokensPerQuery() {
        // Base Sonnet-equivalent tokens
        XCTAssertEqual(WorkloadProfile.lightChat.tokensPerQuery, 800)
        XCTAssertEqual(WorkloadProfile.coding.tokensPerQuery, 3_500)
        XCTAssertEqual(WorkloadProfile.longContextAnalysis.tokensPerQuery, 10_000)

        // Model-adjusted tokens
        XCTAssertEqual(WorkloadProfile.lightChat.tokensPerQuery(for: .haiku), 480)   // 800 * 0.6
        XCTAssertEqual(WorkloadProfile.coding.tokensPerQuery(for: .opus), 7_000)     // 3500 * 2.0
    }

    func test_plan_baseQueryLimit() {
        // Sonnet baseline
        XCTAssertEqual(Plan.pro.baseQueryLimit(for: .sonnet), 45)
        XCTAssertGreaterThan(Plan.max.baseQueryLimit(for: .sonnet), Plan.pro.baseQueryLimit(for: .sonnet))

        // Haiku allows more queries
        XCTAssertEqual(Plan.pro.baseQueryLimit(for: .haiku), 58)   // 45 * 1.3
        // Opus allows fewer
        XCTAssertEqual(Plan.pro.baseQueryLimit(for: .opus), 27)    // 45 * 0.6
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

    func test_claudeModel_pricing() {
        // April 2026 pricing per million tokens
        XCTAssertEqual(ClaudeModel.haiku.inputPricePerMTokens, 1.0)
        XCTAssertEqual(ClaudeModel.sonnet.inputPricePerMTokens, 3.0)
        XCTAssertEqual(ClaudeModel.opus.inputPricePerMTokens, 5.0)

        // Opus should cost more per query than Sonnet
        XCTAssertGreaterThan(ClaudeModel.opus.estimatedCostPerQueryCents,
                             ClaudeModel.sonnet.estimatedCostPerQueryCents)
        // Haiku should be cheapest
        XCTAssertLessThan(ClaudeModel.haiku.estimatedCostPerQueryCents,
                          ClaudeModel.sonnet.estimatedCostPerQueryCents)
    }
}
