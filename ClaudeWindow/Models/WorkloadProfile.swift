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

    /// Average tokens consumed per query (prompt + response, heuristic).
    var tokensPerQuery: Int {
        switch self {
        case .lightChat:           return 500
        case .standardWriting:     return 1_200
        case .coding:              return 2_000
        case .longContextAnalysis: return 8_000
        case .documentHeavy:       return 12_000
        }
    }
}
