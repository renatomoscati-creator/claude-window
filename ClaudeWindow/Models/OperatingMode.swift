import Foundation

enum OperatingMode: String, Codable, CaseIterable {
    case limitRisk   = "limit_risk"
    case reliability = "reliability"

    var displayName: String {
        switch self {
        case .limitRisk:   return "Limit Risk"
        case .reliability: return "Reliability"
        }
    }
}
