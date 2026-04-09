import Foundation

enum ClaudeModel: String, Codable, CaseIterable, Identifiable {
    case haiku  = "haiku"
    case sonnet = "sonnet"
    case opus   = "opus"

    var id: String { rawValue }

    /// Display name with version (April 2026).
    var displayName: String {
        switch self {
        case .haiku:  return "Haiku 4.5"
        case .sonnet: return "Sonnet 4.6"
        case .opus:   return "Opus 4.6"
        }
    }

    /// Short name for compact UI (picker segments, badges).
    var shortName: String {
        switch self {
        case .haiku:  return "Haiku"
        case .sonnet: return "Sonnet"
        case .opus:   return "Opus"
        }
    }

    /// Relative token consumption multiplier vs Sonnet baseline (1.0).
    ///
    /// Derived from the API pricing ratio (input $/Mtok): Haiku $1, Sonnet $3, Opus $5.
    /// Empirically confirmed by observed session capacities — Sonnet delivers ≈3× fewer
    /// queries than Haiku and Opus ≈1.67× fewer than Sonnet on the same plan budget.
    ///
    ///   Haiku  = 1/3  ≈ 0.33  (3× cheaper per token than Sonnet)
    ///   Sonnet = 1.0          (baseline)
    ///   Opus   = 5/3  ≈ 1.67  (5/3× more expensive than Sonnet, 5× vs Haiku)
    var tokensPerQueryMultiplier: Double {
        switch self {
        case .haiku:  return 1.0 / 3.0   // ≈ 0.333
        case .sonnet: return 1.0
        case .opus:   return 5.0 / 3.0   // ≈ 1.667
        }
    }

    /// API pricing per million tokens (April 2026).
    var inputPricePerMTokens: Double {
        switch self {
        case .haiku:  return 1.00
        case .sonnet: return 3.00
        case .opus:   return 5.00
        }
    }

    var outputPricePerMTokens: Double {
        switch self {
        case .haiku:  return 5.00
        case .sonnet: return 15.00
        case .opus:   return 25.00
        }
    }

    /// Estimated cost per average query (input + output) in USD cents.
    /// Assumes ~50% input / 50% output token split for a typical interaction.
    var estimatedCostPerQueryCents: Double {
        let avgTokensPerQuery = 2000.0  // baseline Sonnet-equivalent tokens
        let effectiveTokens = avgTokensPerQuery * tokensPerQueryMultiplier
        let inputCost  = (effectiveTokens * 0.5) / 1_000_000 * inputPricePerMTokens
        let outputCost = (effectiveTokens * 0.5) / 1_000_000 * outputPricePerMTokens
        return (inputCost + outputCost) * 100.0
    }
}
