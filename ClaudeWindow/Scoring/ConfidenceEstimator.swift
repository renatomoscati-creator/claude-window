import Foundation

enum ConfidenceEstimator {

    static func estimate(
        serviceStatus: ServiceStatus,
        hasUserHistory: Bool,
        efficiencyScore: Int,
        reliabilityScore: Int
    ) -> Confidence {
        var points = 0

        // Status freshness
        let age = Date().timeIntervalSince(serviceStatus.fetchedAt)
        if age < 300      { points += 2 }   // fresh
        else if age < 600 { points += 1 }   // slightly stale
        // > 600s adds 0

        // Signal agreement
        let divergence = abs(efficiencyScore - reliabilityScore)
        if divergence < 20      { points += 2 }
        else if divergence < 40 { points += 1 }

        // User history
        if hasUserHistory { points += 1 }

        switch points {
        case 5...: return .high
        case 3...4: return .medium
        default:    return .low
        }
    }
}
