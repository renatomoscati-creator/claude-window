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

    /// Multiplier applied to raw time-of-day pressure for this surface.
    /// Claude Code runs long tool-calling sessions that bite rate limits
    /// harder during peaks; API users self-pace more smoothly than chat.
    /// Heuristic — calibrate once real usage data is available.
    var pressureMultiplier: Double {
        switch self {
        case .desktop: return 1.00
        case .code:    return 1.15
        case .api:     return 0.90
        }
    }

    /// Scales incident/degradation penalties. API is most directly exposed
    /// to backend availability; desktop chat tolerates brief hiccups; Code
    /// falls between (background tool calls can fail mid-session).
    var reliabilitySensitivity: Double {
        switch self {
        case .desktop: return 0.85
        case .code:    return 1.00
        case .api:     return 1.20
        }
    }
}
