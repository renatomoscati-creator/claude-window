import Foundation

enum WorkloadProfile: String, Codable, CaseIterable {
    case lightChat           = "light_chat"
    case standardWriting     = "standard_writing"
    case coding              = "coding"
    case longContextAnalysis = "long_context_analysis"
    case documentHeavy       = "document_heavy"

    var displayName: String {
        switch self {
        case .lightChat:           return "Light chat"
        case .standardWriting:     return "Standard writing / research"
        case .coding:              return "Coding"
        case .longContextAnalysis: return "Long-context analysis"
        case .documentHeavy:       return "File-heavy / document-heavy"
        }
    }

    /// Session-average tokens per query (prompt + completion, Sonnet baseline).
    ///
    /// These represent the *mean* across a typical session, not first-query cost.
    /// Context accumulates quadratically (each turn includes all prior turns), so
    /// early queries are cheap and late queries are expensive. The values here
    /// encode a session-weighted average derived from empirical Reddit/usage data
    /// (April 2026):
    ///
    ///   lightChat:           early 1-3k, late 5-10k   → avg ≈ 1.5k
    ///   standardWriting:     early 2-5k, late 8-15k   → avg ≈ 3k
    ///   coding:              early 5-15k, late 20-50k → avg ≈ 5k
    ///   longContextAnalysis: large fixed context       → avg ≈ 20k
    ///   documentHeavy:       document re-injection     → avg ≈ 40k
    ///
    /// Apply model multiplier (ClaudeModel.tokensPerQueryMultiplier) on top:
    ///   Haiku ×0.33 · Sonnet ×1.0 · Opus ×1.67
    var tokensPerQuery: Int {
        switch self {
        case .lightChat:           return 1_500
        case .standardWriting:     return 2_000
        case .coding:              return 4_000
        case .longContextAnalysis: return 15_000
        case .documentHeavy:       return 35_000
        }
    }

    /// Adjusted tokens for a specific model.
    func tokensPerQuery(for model: ClaudeModel) -> Int {
        Int(Double(tokensPerQuery) * model.tokensPerQueryMultiplier)
    }
}
