import Foundation

enum LimitEfficiencyScorer {

    static func score(
        at date: Date = Date(),
        serviceStatus: ServiceStatus,
        holidayRegions: Set<HolidayRegion>,
        surface: Surface = .desktop
    ) -> WindowScore {
        let basePressure = TimingHeuristics.pressureScore(at: date, holidayRegions: holidayRegions)
        // Surface-aware adjustment so Desktop/Code/API don't all score identically.
        let pressure = min(1.0, max(0.0, basePressure * surface.pressureMultiplier))

        // Base efficiency: inverse of pressure, scaled to 0-100 with floor of 15
        var rawScore = (1.0 - pressure) * 85.0 + 15.0

        if serviceStatus.hasActiveIncident {
            rawScore -= Double(serviceStatus.degradedComponentCount) * 6.0
        }
        if serviceStatus.indicator == "major" || serviceStatus.indicator == "critical" {
            rawScore -= 15.0
        }

        let finalScore = Int(min(max(rawScore, 0), 100))
        let state = windowState(for: finalScore)
        let reasons = buildReasons(
            pressure: pressure, date: date,
            serviceStatus: serviceStatus, holidayRegions: holidayRegions
        )
        return WindowScore(score: finalScore, state: state, confidence: .medium, reasons: reasons)
    }

    private static func windowState(for score: Int) -> WindowState {
        switch score {
        case 70...100: return .efficient
        case 40..<70:  return .average
        case 22..<40:  return .highRisk
        default:       return .poor
        }
    }

    private static func buildReasons(
        pressure: Double, date: Date,
        serviceStatus: ServiceStatus, holidayRegions: Set<HolidayRegion>
    ) -> [String] {
        // This scorer only explains USAGE / RATE-LIMIT pressure from time of
        // day, region overlap, and holidays. Service-health signals belong in
        // ReliabilityScorer's reasons, not here.
        var reasons: [String] = []
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC") ?? TimeZone(secondsFromGMT: 0) ?? .current
        let hour    = cal.component(.hour,    from: date)
        let weekday = cal.component(.weekday, from: date)
        let isWeekend = weekday == 1 || weekday == 7

        // Pressure buckets always say something — leaving the 0.30-0.65 band
        // empty caused the yellow-state-with-no-explanation bug.
        if pressure < 0.30 {
            reasons.append("Off-peak US hours. Low estimated demand.")
        } else if pressure < 0.55 {
            reasons.append("Moderate regional load. Mixed demand across regions.")
        } else if pressure < 0.75 {
            reasons.append("Elevated regional load. Multiple regions in business hours.")
        } else {
            reasons.append("Peak global load. US business hours overlapping other regions.")
        }
        if hour >= 1 && hour <= 7 {
            reasons.append("US overnight. Historically favorable window.")
        }
        if isWeekend {
            reasons.append("Weekend effect. Reduced regional business-hour overlap.")
        }
        if TimingHeuristics.hasActiveHoliday(on: date, in: holidayRegions) {
            reasons.append("Regional holiday(s) reduce expected demand.")
        }
        // Only swap in a friendly cheerleader message when pressure is
        // genuinely low. A "clear runway ahead" line alongside a yellow state
        // would lie about the window.
        if pressure < 0.25, reasons.count == 1 {
            reasons[0] = Self.quietFallbacks[hour % Self.quietFallbacks.count]
        }
        return Array(reasons.prefix(5))
    }

    private static let quietFallbacks: [String] = [
        "There is no reason to not make the most of this!",
        "Nothing flagged. Clear runway ahead.",
        "No warning signs. Great moment to push.",
        "All quiet on the limits front. Go ship something."
    ]
}
