import XCTest
@testable import ClaudeWindow

final class CapacityEstimatorTests: XCTestCase {

    func test_proLightChat_offPeak_highQueryRange() {
        let capacity = CapacityEstimator.estimate(
            efficiencyScore: 85, plan: .pro, model: .sonnet, workload: .lightChat, confidence: .medium
        )
        XCTAssertGreaterThan(capacity.maxQueries, 30)
        XCTAssertLessThan(capacity.minQueries, capacity.maxQueries)
    }

    func test_proHeavyWorkload_peakHours_lowQueryRange() {
        let capacity = CapacityEstimator.estimate(
            efficiencyScore: 30, plan: .pro, model: .sonnet, workload: .documentHeavy, confidence: .medium
        )
        XCTAssertLessThan(capacity.maxQueries, 20)
    }

    func test_maxPlan_hasMoreCapacityThanPro() {
        let pro = CapacityEstimator.estimate(efficiencyScore: 80, plan: .pro, model: .sonnet, workload: .coding, confidence: .medium)
        let max = CapacityEstimator.estimate(efficiencyScore: 80, plan: .max, model: .sonnet, workload: .coding, confidence: .medium)
        XCTAssertGreaterThan(max.maxQueries, pro.maxQueries)
    }

    func test_minIsAlwaysLessThanMax() {
        for score in stride(from: 0, through: 100, by: 10) {
            let cap = CapacityEstimator.estimate(efficiencyScore: score, plan: .pro, model: .sonnet, workload: .standardWriting, confidence: .medium)
            XCTAssertLessThanOrEqual(cap.minQueries, cap.maxQueries)
            XCTAssertLessThanOrEqual(cap.minTokens, cap.maxTokens)
        }
    }

    func test_tokensConsistentWithQueries() {
        let cap = CapacityEstimator.estimate(efficiencyScore: 70, plan: .pro, model: .sonnet, workload: .coding, confidence: .medium)
        let expectedApprox = cap.minQueries * WorkloadProfile.coding.tokensPerQuery(for: .sonnet)
        XCTAssertGreaterThan(cap.minTokens, expectedApprox / 2)
    }

    // MARK: — Model-specific tests

    func test_opusUsesMoreTokensPerQuery() {
        let sonnetCap = CapacityEstimator.estimate(efficiencyScore: 70, plan: .pro, model: .sonnet, workload: .coding, confidence: .medium)
        let opusCap = CapacityEstimator.estimate(efficiencyScore: 70, plan: .pro, model: .opus, workload: .coding, confidence: .medium)
        // Opus uses 2x tokens/query, so tokens should be ~2x even with fewer queries
        XCTAssertGreaterThan(opusCap.maxTokens, sonnetCap.maxTokens)
    }

    func test_haikuUsesFewerTokensPerQuery() {
        let sonnetCap = CapacityEstimator.estimate(efficiencyScore: 70, plan: .pro, model: .sonnet, workload: .coding, confidence: .medium)
        let haikuCap = CapacityEstimator.estimate(efficiencyScore: 70, plan: .pro, model: .haiku, workload: .coding, confidence: .medium)
        // Haiku uses 0.6x tokens/query and can squeeze more queries in
        XCTAssertLessThan(haikuCap.maxTokens, sonnetCap.maxTokens)
    }

    func test_modelAffectsQueryCapacity() {
        // Haiku allows more queries per window, Opus fewer
        let haikuCap = CapacityEstimator.estimate(efficiencyScore: 80, plan: .pro, model: .haiku, workload: .lightChat, confidence: .high)
        let opusCap = CapacityEstimator.estimate(efficiencyScore: 80, plan: .pro, model: .opus, workload: .lightChat, confidence: .high)
        XCTAssertGreaterThan(haikuCap.maxQueries, opusCap.maxQueries)
    }
}
