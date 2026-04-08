import Foundation

enum Plan: String, Codable, CaseIterable {
    case free    = "free"
    case pro     = "pro"
    case max5    = "max5"
    case max20   = "max20"
    case custom  = "custom"

    /// Approximate token budget per 5-hour rolling window.
    /// Single source of truth — query counts derived by dividing by tokensPerQuery.
    ///
    /// Calibrated to Anthropic's published limits (April 2026):
    ///   Free   → ~10 queries  × 2 000 t =   20 000 t
    ///   Pro    → ~45 queries  × 2 000 t =   90 000 t
    ///   Max 5× → ~225 queries × 2 000 t =  450 000 t  (5× Pro)
    ///   Max 20×→ ~900 queries × 2 000 t = 1 800 000 t (20× Pro)
    var tokenBudget: Int {
        switch self {
        case .free:   return 20_000
        case .pro:    return 90_000
        case .max5:   return 450_000
        case .max20:  return 1_800_000
        case .custom: return 90_000   // overridden by CustomPlanSettings.baseTokenLimit
        }
    }

    /// Derived query limit for a given model and workload.
    /// Haiku → more queries, Opus → fewer; token ceiling stays fixed per plan.
    func baseQueryLimit(for model: ClaudeModel = .sonnet,
                        workload: WorkloadProfile = .standardWriting) -> Int {
        let tpq = workload.tokensPerQuery(for: model)
        return Swift.max(1, tokenBudget / tpq)
    }

    var displayName: String {
        switch self {
        case .free:   return "Free"
        case .pro:    return "Pro"
        case .max5:   return "Max 5×"
        case .max20:  return "Max 20×"
        case .custom: return "Custom"
        }
    }
}

struct CustomPlanSettings: Codable, Equatable {
    var baseQueryLimit: Int = 45
    var baseTokenLimit: Int = 200_000
}
