import Foundation

enum LimitEfficiencyScorer {

    static func score(
        at date: Date = Date(),
        serviceStatus: ServiceStatus,
        holidayRegions: Set<HolidayRegion>
    ) -> WindowScore {
        let pressure = TimingHeuristics.pressureScore(at: date, holidayRegions: holidayRegions)

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
        var reasons: [String] = []
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        let hour    = cal.component(.hour,    from: date)
        let weekday = cal.component(.weekday, from: date)
        let isWeekend = weekday == 1 || weekday == 7

        if pressure < 0.3 {
            reasons.append("Off-peak US hours — low estimated demand")
        } else if pressure > 0.65 {
            reasons.append("Peak US business hours — elevated estimated demand")
        }
        if hour >= 1 && hour <= 7 {
            reasons.append("US overnight — historically favorable window")
        }
        if isWeekend {
            reasons.append("Weekend effect — reduced regional business-hour overlap")
        }
        if serviceStatus.hasActiveIncident {
            reasons.append("Active service incident may affect session quality")
        } else if serviceStatus.indicator == "none" {
            reasons.append("No active incidents — service status normal")
        }
        if serviceStatus.degradedComponentCount > 0 {
            reasons.append("\(serviceStatus.degradedComponentCount) component(s) currently degraded")
        }
        if TimingHeuristics.hasActiveHoliday(on: date, in: holidayRegions) {
            reasons.append("Regional holiday(s) reduce expected demand")
        }
        return Array(reasons.prefix(5))
    }
}
