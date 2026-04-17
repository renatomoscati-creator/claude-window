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
        let tpq = Swift.max(1, workload.tokensPerQuery(for: model))
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
    private var _baseQueryLimit: Int = 45
    private var _baseTokenLimit: Int = 200_000

    var baseQueryLimit: Int {
        get { _baseQueryLimit }
        set { _baseQueryLimit = Swift.max(1, newValue) }
    }
    var baseTokenLimit: Int {
        get { _baseTokenLimit }
        set { _baseTokenLimit = Swift.max(1, newValue) }
    }

    init(baseQueryLimit: Int = 45, baseTokenLimit: Int = 200_000) {
        self._baseQueryLimit = Swift.max(1, baseQueryLimit)
        self._baseTokenLimit = Swift.max(1, baseTokenLimit)
    }

    // Decode legacy payloads that stored the public names.
    enum CodingKeys: String, CodingKey {
        case baseQueryLimit, baseTokenLimit
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self._baseQueryLimit = Swift.max(1, try c.decodeIfPresent(Int.self, forKey: .baseQueryLimit) ?? 45)
        self._baseTokenLimit = Swift.max(1, try c.decodeIfPresent(Int.self, forKey: .baseTokenLimit) ?? 200_000)
    }
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(_baseQueryLimit, forKey: .baseQueryLimit)
        try c.encode(_baseTokenLimit, forKey: .baseTokenLimit)
    }
}
