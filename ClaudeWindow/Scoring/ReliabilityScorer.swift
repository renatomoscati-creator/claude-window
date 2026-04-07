import Foundation

enum ReliabilityScorer {

    static func score(serviceStatus: ServiceStatus) -> WindowScore {
        guard serviceStatus.indicator != "unknown" else {
            return WindowScore(score: 50, state: .unknown, confidence: .low,
                               reasons: ["Service status unavailable — confidence low"])
        }

        var raw = 100.0

        switch serviceStatus.indicator {
        case "none":     raw -= 0
        case "minor":    raw -= 15
        case "major":    raw -= 40
        case "critical": raw -= 65
        default:         raw -= 20
        }

        raw -= Double(serviceStatus.degradedComponentCount) * 8.0
        raw -= Double(serviceStatus.recentIncidentCount) * 10.0
        if serviceStatus.hasActiveIncident { raw -= 12.0 }

        let finalScore = Int(min(max(raw, 0), 100))
        let state      = windowState(for: finalScore)
        let conf       = confidence(for: serviceStatus)
        let reasons    = buildReasons(serviceStatus: serviceStatus)
        return WindowScore(score: finalScore, state: state, confidence: conf, reasons: reasons)
    }

    private static func windowState(for score: Int) -> WindowState {
        // Unified thresholds with LimitEfficiencyScorer for consistent UI coloring:
        // 70+ = green (good), 45-69 = yellow (average), 25-44 = orange (risky), <25 = red (poor)
        switch score {
        case 70...100: return .efficient
        case 45..<70:  return .average
        case 25..<45:  return .highRisk
        default:       return .poor
        }
    }

    private static func confidence(for status: ServiceStatus) -> Confidence {
        if status.indicator == "unknown" { return .low }
        let age = Date().timeIntervalSince(status.fetchedAt)
        if age > 600 { return .low }
        if age > 300 { return .medium }
        return .high
    }

    private static func buildReasons(serviceStatus: ServiceStatus) -> [String] {
        var reasons: [String] = []
        switch serviceStatus.indicator {
        case "none":     reasons.append("Current official status: All Systems Operational")
        case "minor":    reasons.append("Active minor service disruption")
        case "major":    reasons.append("Active major service incident")
        case "critical": reasons.append("Critical service outage in progress")
        default:         reasons.append("Service status unknown or unavailable")
        }
        if serviceStatus.degradedComponentCount > 0 {
            reasons.append("\(serviceStatus.degradedComponentCount) component(s) degraded")
        }
        if serviceStatus.hasActiveIncident {
            reasons.append("Unresolved incident(s) currently active")
        }
        if serviceStatus.recentIncidentCount == 0 && serviceStatus.indicator == "none" {
            reasons.append("No recent incidents — stability looks good")
        }
        return Array(reasons.prefix(4))
    }
}
