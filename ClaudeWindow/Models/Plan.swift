import Foundation

enum Plan: String, Codable, CaseIterable {
    case free   = "free"
    case pro    = "pro"
    case max    = "max"
    case custom = "custom"

    /// Approximate query limit per 5-hour rolling window (heuristic, not official).
    var baseQueryLimit: Int {
        switch self {
        case .free:   return 10
        case .pro:    return 45
        case .max:    return 100
        case .custom: return 45   // overridden by CustomPlanSettings
        }
    }

    var displayName: String { rawValue.capitalized }
}

struct CustomPlanSettings: Codable, Equatable {
    var baseQueryLimit: Int = 45
    var baseTokenLimit: Int = 200_000
}
