import Foundation

enum Plan: String, Codable, CaseIterable {
    case free   = "free"
    case pro    = "pro"
    case max    = "max"
    case custom = "custom"

    /// Approximate token budget per 5-hour rolling window.
    /// This is the single source of truth for capacity — query counts are
    /// derived by dividing this by tokensPerQuery(for: model).
    ///
    /// Calibrated to match Anthropic's published Pro/Max message limits
    /// using ~2 000 tokens/query (Sonnet, standard workload) as the baseline:
    ///   Free  → ~10 queries × 2 000  =  20 000 t
    ///   Pro   → ~45 queries × 2 000  =  90 000 t
    ///   Max   → ~225 queries × 2 000 = 450 000 t
    var tokenBudget: Int {
        switch self {
        case .free:   return 20_000
        case .pro:    return 90_000
        case .max:    return 450_000
        case .custom: return 90_000   // overridden by CustomPlanSettings.baseTokenLimit
        }
    }

    /// Derived query limit for a given model and workload.
    /// Using the token budget as the primary constraint ensures that switching
    /// models changes the query ceiling consistently: Haiku → more queries,
    /// Opus → fewer, while the token ceiling stays fixed per plan.
    func baseQueryLimit(for model: ClaudeModel = .sonnet,
                        workload: WorkloadProfile = .standardWriting) -> Int {
        let tpq = workload.tokensPerQuery(for: model)
        return Swift.max(1, tokenBudget / tpq)
    }

    var displayName: String { rawValue.capitalized }
}

struct CustomPlanSettings: Codable, Equatable {
    var baseQueryLimit: Int = 45
    var baseTokenLimit: Int = 200_000
}
