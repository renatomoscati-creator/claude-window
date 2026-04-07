import Foundation

enum Plan: String, Codable, CaseIterable {
    case free   = "free"
    case pro    = "pro"
    case max    = "max"
    case custom = "custom"

    /// Approximate query limit per 5-hour rolling window (heuristic, not official).
    /// Based on 2026 Anthropic published limits for Sonnet.
    /// Free: ~10, Pro: ~45, Max 5x: ~200
    func baseQueryLimit(for model: ClaudeModel = .sonnet) -> Int {
        let base: Int
        switch self {
        case .free:   base = 10
        case .pro:    base = 45
        case .max:    base = 200
        case .custom: base = 45
        }
        // Opus consumes quota faster (heavier responses), Haiku slower.
        // These are approximate multipliers based observed 5h window exhaustion rates.
        let modelAdjustment: Double
        switch model {
        case .haiku:  modelAdjustment = 1.3   // can squeeze more queries in
        case .sonnet: modelAdjustment = 1.0
        case .opus:   modelAdjustment = 0.6   // burns through quota faster
        }
        return Int(Double(base) * modelAdjustment)
    }

    var displayName: String { rawValue.capitalized }
}

struct CustomPlanSettings: Codable, Equatable {
    var baseQueryLimit: Int = 45
    var baseTokenLimit: Int = 200_000
}
