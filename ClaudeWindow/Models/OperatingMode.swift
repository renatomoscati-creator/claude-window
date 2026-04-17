import Foundation

enum OperatingMode: String, Codable, CaseIterable {
    case limitRisk   = "limit_risk"
    case reliability = "reliability"

    var displayName: String {
        switch self {
        case .limitRisk:   return "Usage Limits"
        case .reliability: return "Reliability"
        }
    }

    /// Subtitle explaining what this mode scores.
    var shortDescription: String {
        switch self {
        case .limitRisk:
            return "Risk of hitting your plan's usage limits in this window"
        case .reliability:
            return "Likelihood of uninterrupted sessions right now"
        }
    }
}
