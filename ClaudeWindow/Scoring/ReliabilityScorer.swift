import Foundation

enum ReliabilityScorer {

    static func score(serviceStatus: ServiceStatus, surface: Surface = .desktop) -> WindowScore {
        guard serviceStatus.indicator != "unknown" else {
            return WindowScore(score: 50, state: .unknown, confidence: .low,
                               reasons: ["Service status unavailable — confidence low"])
        }

        var raw = 100.0
        let sensitivity = surface.reliabilitySensitivity

        switch serviceStatus.indicator {
        case "none":     raw -= 0
        case "minor":    raw -= 15 * sensitivity
        case "major":    raw -= 40 * sensitivity
        case "critical": raw -= 65 * sensitivity
        default:         raw -= 20 * sensitivity
        }

        raw -= Double(serviceStatus.degradedComponentCount) * 8.0 * sensitivity
        raw -= Double(serviceStatus.recentIncidentCount) * 10.0 * sensitivity
        if serviceStatus.hasActiveIncident { raw -= 12.0 * sensitivity }

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

        // Clean bill of health: swap the dry "All Systems Operational" line
        // for a rotating friendly one. Cycles hourly so it varies over time
        // but stays stable within an hour so refreshes don't flicker it.
        let allClear = serviceStatus.indicator == "none"
            && !serviceStatus.hasActiveIncident
            && serviceStatus.degradedComponentCount == 0
            && serviceStatus.recentIncidentCount == 0
        if allClear {
            let hour = Calendar.current.component(.hour, from: Date())
            reasons.append(Self.operationalFallbacks[hour % Self.operationalFallbacks.count])
            return reasons
        }

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

    private static let operationalFallbacks: [String] = [
        "All systems humming — nothing stands between you and a great session.",
        "Green across the board. Make it count.",
        "Anthropic is happy, servers are happy. Your turn.",
        "No incidents, no hiccups. Clear skies overhead."
    ]
}
