import SwiftUI

enum TimeZoneFormatting {
    /// Returns e.g. "UTC+2" or "UTC-5:30" (CEST/CET suffix uses localized abbreviation).
    static func offsetString(for tz: TimeZone, on date: Date = Date()) -> String {
        let seconds = tz.secondsFromGMT(for: date)
        let sign = seconds >= 0 ? "+" : "-"
        let abs = Swift.abs(seconds)
        let hours = abs / 3600
        let minutes = (abs % 3600) / 60
        if minutes == 0 {
            return "UTC\(sign)\(hours)"
        }
        return "UTC\(sign)\(hours):\(String(format: "%02d", minutes))"
    }

    /// Short abbreviation + offset, e.g. "CEST · UTC+2".
    static func abbrAndOffset(for tz: TimeZone, on date: Date = Date()) -> String {
        let abbr = tz.abbreviation(for: date) ?? tz.identifier
        return "\(abbr) · \(offsetString(for: tz, on: date))"
    }

    /// Menu label: "Europe/Rome (UTC+2)".
    static func menuLabel(for identifier: String, on date: Date = Date()) -> String {
        let tz = TimeZone(identifier: identifier) ?? .current
        return "\(identifier) (\(offsetString(for: tz, on: date)))"
    }

    /// IANA identifiers sorted by current offset then alphabetically — easier to scan.
    static var sortedIdentifiers: [String] {
        let now = Date()
        return TimeZone.knownTimeZoneIdentifiers.sorted { a, b in
            let ta = TimeZone(identifier: a)?.secondsFromGMT(for: now) ?? 0
            let tb = TimeZone(identifier: b)?.secondsFromGMT(for: now) ?? 0
            if ta != tb { return ta < tb }
            return a < b
        }
    }
}

/// Reusable timezone picker. Shows offset next to the identifier.
struct TimeZoneSettingPicker: View {
    @Binding var selection: String
    var label: String = "Forecast Timezone"

    var body: some View {
        Picker(label, selection: $selection) {
            ForEach(TimeZoneFormatting.sortedIdentifiers, id: \.self) { id in
                Text(TimeZoneFormatting.menuLabel(for: id)).tag(id)
            }
        }
    }
}
