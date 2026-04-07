import XCTest
@testable import ClaudeWindow

final class CapacityEstimatorTests: XCTestCase {

    func test_proLightChat_offPeak_highQueryRange() {
        let capacity = CapacityEstimator.estimate(
            efficiencyScore: 85, plan: .pro, workload: .lightChat, confidence: .medium
        )
        XCTAssertGreaterThan(capacity.maxQueries, 30)
        XCTAssertLessThan(capacity.minQueries, capacity.maxQueries)
    }

    func test_proHeavyWorkload_peakHours_lowQueryRange() {
        let capacity = CapacityEstimator.estimate(
            efficiencyScore: 30, plan: .pro, workload: .documentHeavy, confidence: .medium
        )
        XCTAssertLessThan(capacity.maxQueries, 20)
    }

    func test_maxPlan_hasMoreCapacityThanPro() {
        let pro = CapacityEstimator.estimate(efficiencyScore: 80, plan: .pro, workload: .coding, confidence: .medium)
        let max = CapacityEstimator.estimate(efficiencyScore: 80, plan: .max, workload: .coding, confidence: .medium)
        XCTAssertGreaterThan(max.maxQueries, pro.maxQueries)
    }

    func test_minIsAlwaysLessThanMax() {
        for score in stride(from: 0, through: 100, by: 10) {
            let cap = CapacityEstimator.estimate(efficiencyScore: score, plan: .pro, workload: .standardWriting, confidence: .medium)
            XCTAssertLessThanOrEqual(cap.minQueries, cap.maxQueries)
            XCTAssertLessThanOrEqual(cap.minTokens, cap.maxTokens)
        }
    }

    func test_tokensConsistentWithQueries() {
        let cap = CapacityEstimator.estimate(efficiencyScore: 70, plan: .pro, workload: .coding, confidence: .medium)
        let expectedApprox = cap.minQueries * WorkloadProfile.coding.tokensPerQuery
        XCTAssertGreaterThan(cap.minTokens, expectedApprox / 2)
    }
}
