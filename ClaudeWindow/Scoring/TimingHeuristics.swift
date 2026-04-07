import Foundation

enum HolidayRegion: String, Codable, CaseIterable {
    case us   = "us"
    case eu   = "eu"
    case uk   = "uk"
    case apac = "apac"

    var displayName: String {
        switch self {
        case .us:   return "United States"
        case .eu:   return "Europe"
        case .uk:   return "United Kingdom"
        case .apac: return "Asia-Pacific"
        }
    }
}

struct HourWindow {
    let startHour: Int   // UTC
    let endHour: Int     // UTC
    let pressureScore: Double
}

enum TimingHeuristics {

    // MARK: — Public API

    /// Returns 0.0 (low pressure = good for user) to 1.0 (high pressure = bad).
    static func pressureScore(
        at date: Date = Date(),
        holidayRegions: Set<HolidayRegion> = []
    ) -> Double {
        let utcCal = utcCalendar()
        let hour    = utcCal.component(.hour,    from: date)
        let weekday = utcCal.component(.weekday, from: date)  // 1=Sun, 7=Sat
        let isWeekend = weekday == 1 || weekday == 7

        let usLoad   = usRegionalLoad(utcHour: hour,
                                      holiday: isHoliday(date, region: .us,   regions: holidayRegions))
        let euLoad   = euRegionalLoad(utcHour: hour,
                                      holiday: isHoliday(date, region: .eu,   regions: holidayRegions))
        let apacLoad = apacRegionalLoad(utcHour: hour,
                                        holiday: isHoliday(date, region: .apac, regions: holidayRegions))

        // Weighted: US drives the most Claude traffic
        var combined = usLoad * 0.65 + euLoad * 0.20 + apacLoad * 0.15

        // Weekend reduction
        if isWeekend { combined *= 0.55 }

        // Seasonal adjustments
        let month = utcCal.component(.month, from: date)
        if month == 12 || month == 1 { combined *= 0.88 }
        else if month == 8           { combined *= 1.06 }

        return min(max(combined, 0.0), 1.0)
    }

    /// Returns low-pressure hour windows within lookAheadHours, sorted by ascending pressure.
    static func bestOffPeakWindows(
        from date: Date = Date(),
        lookAheadHours: Int = 24,
        holidayRegions: Set<HolidayRegion> = []
    ) -> [HourWindow] {
        let cal = utcCalendar()
        var windows: [HourWindow] = []

        for offset in 0..<lookAheadHours {
            guard let candidate = cal.date(byAdding: .hour, value: offset, to: date) else { continue }
            let hour     = cal.component(.hour, from: candidate)
            let pressure = pressureScore(at: candidate, holidayRegions: holidayRegions)
            windows.append(HourWindow(startHour: hour, endHour: (hour + 1) % 24, pressureScore: pressure))
        }

        return windows
            .filter { $0.pressureScore < 0.45 }
            .sorted { $0.pressureScore < $1.pressureScore }
    }

    // MARK: — Private helpers

    private static func utcCalendar() -> Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal
    }

    /// US load peaks 14:00–22:00 UTC (9am–5pm ET / 6am–2pm PT).
    private static func usRegionalLoad(utcHour: Int, holiday: Bool) -> Double {
        let load = bellCurve(hour: utcHour, peakHour: 18, halfWidthHours: 5)
        return holiday ? load * 0.25 : load
    }

    /// EU load peaks 08:00–16:00 UTC (9am–5pm CET).
    private static func euRegionalLoad(utcHour: Int, holiday: Bool) -> Double {
        let load = bellCurve(hour: utcHour, peakHour: 12, halfWidthHours: 4)
        return holiday ? load * 0.30 : load
    }

    /// APAC load peaks 01:00–08:00 UTC (9am–5pm JST/SGT/AEST).
    private static func apacRegionalLoad(utcHour: Int, holiday: Bool) -> Double {
        let load = bellCurve(hour: utcHour, peakHour: 4, halfWidthHours: 4)
        return holiday ? load * 0.35 : load
    }

    /// Smooth bell-curve 0–1, centered on peakHour, handles midnight wraparound.
    private static func bellCurve(hour: Int, peakHour: Int, halfWidthHours: Double) -> Double {
        var delta = Double(hour - peakHour)
        if delta >  12 { delta -= 24 }
        if delta < -12 { delta += 24 }
        return exp(-(delta * delta) / (2 * halfWidthHours * halfWidthHours))
    }

    // MARK: — Holiday detection

    private static func isHoliday(_ date: Date, region: HolidayRegion, regions: Set<HolidayRegion>) -> Bool {
        guard regions.contains(region) else { return false }
        let cal   = utcCalendar()
        let month = cal.component(.month, from: date)
        let day   = cal.component(.day,   from: date)

        switch region {
        case .us:
            let usHolidays: [(Int, Int)] = [(1,1),(7,4),(11,11),(12,25),(12,26)]
            return usHolidays.contains { $0.0 == month && $0.1 == day }
        case .eu, .uk:
            let euHolidays: [(Int, Int)] = [(1,1),(12,25),(12,26)]
            return euHolidays.contains { $0.0 == month && $0.1 == day }
        case .apac:
            if month == 2 && day <= 7 { return true }  // Chinese New Year approx.
            return [(1,1),(12,25)].contains { $0.0 == month && $0.1 == day }
        }
    }
}
