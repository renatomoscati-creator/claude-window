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

    /// Base tokens consumed per query (prompt + response, Sonnet-equivalent).
    /// Updated April 2026 based on observed usage across models.
    var tokensPerQuery: Int {
        switch self {
        case .lightChat:           return 800
        case .standardWriting:     return 2_000
        case .coding:              return 3_500
        case .longContextAnalysis: return 10_000
        case .documentHeavy:       return 18_000
        }
    }

    /// Adjusted tokens for a specific model.
    func tokensPerQuery(for model: ClaudeModel) -> Int {
        Int(Double(tokensPerQuery) * model.tokensPerQueryMultiplier)
    }
}
