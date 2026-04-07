import Foundation

enum Surface: String, Codable, CaseIterable, Identifiable {
    case desktop = "desktop"
    case code    = "code"
    case api     = "api"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .desktop: return "Claude Desktop"
        case .code:    return "Claude Code"
        case .api:     return "Claude API"
        }
    }
}
