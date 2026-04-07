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

    /// Relative token consumption multiplier vs Sonnet baseline (1.0).
    /// Haiku is more concise (~60% of Sonnet tokens/query).
    /// Opus is more verbose and reasoning-heavy (~2.0x Sonnet tokens/query).
    var tokensPerQueryMultiplier: Double {
        switch self {
        case .haiku:  return 0.6
        case .sonnet: return 1.0
        case .opus:   return 2.0
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
