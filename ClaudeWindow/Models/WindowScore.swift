import Foundation
import SwiftUI

enum WindowState: String, Codable {
    case efficient = "efficient"
    case average   = "average"
    case highRisk  = "high_risk"
    case poor      = "poor"
    case unknown   = "unknown"

    var colorName: String {
        switch self {
        case .efficient: return "green"
        case .average:   return "yellow"
        case .highRisk:  return "orange"
        case .poor:      return "red"
        case .unknown:   return "gray"
        }
    }

    var color: Color {
        switch self {
        case .efficient: return .green
        case .average:   return .yellow
        case .highRisk:  return .orange
        case .poor:      return .red
        case .unknown:   return .gray
        }
    }

    var displayLabel: String {
        switch self {
        case .efficient: return "Efficient window"
        case .average:   return "Average window"
        case .highRisk:  return "High limit-risk window"
        case .poor:      return "Poor reliability window"
        case .unknown:   return "Unknown"
        }
    }
}

enum Confidence: String, Codable {
    case high   = "high"
    case medium = "medium"
    case low    = "low"
}

struct WindowScore: Codable, Equatable {
    let score: Int           // 0-100
    let state: WindowState
    let confidence: Confidence
    let reasons: [String]
}
