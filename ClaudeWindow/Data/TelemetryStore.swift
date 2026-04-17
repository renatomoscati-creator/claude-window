import Foundation

struct TelemetryEntry: Codable {
    let date: Date
    let surface: Surface
    let mode: OperatingMode
    let score: Int
    let outcome: TelemetryOutcome
}

enum TelemetryOutcome: String, Codable {
    case hitLimitEarly  = "hit_limit_early"
    case longSession    = "long_session"
    case userReportGood = "user_report_good"
    case userReportBad  = "user_report_bad"
}

final class TelemetryStore {

    private let fileURL: URL
    private var entries: [TelemetryEntry] = []

    init() {
        // Fall back to tmp if Application Support is inaccessible (rare, but sandbox
        // reset or profile weirdness would crash app launch on a force-unwrap).
        let support = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first
            ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        let dir = support.appendingPathComponent("ClaudeWindow", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        fileURL = dir.appendingPathComponent("telemetry.json")
        load()
    }

    func record(_ entry: TelemetryEntry) {
        entries.append(entry)
        if entries.count > 500 { entries.removeFirst(entries.count - 500) }
        save()
    }

    var hasHistory: Bool { !entries.isEmpty }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        entries = (try? JSONDecoder().decode([TelemetryEntry].self, from: data)) ?? []
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        // Atomic so a crash mid-write can't leave a half-file that fails decode next launch.
        try? data.write(to: fileURL, options: .atomic)
    }
}
