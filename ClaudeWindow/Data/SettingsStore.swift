import Foundation

final class SettingsStore: ObservableObject {

    private let defaults: UserDefaults

    init(suiteName: String = "com.claudewindow.app") {
        let ud = UserDefaults(suiteName: suiteName) ?? .standard
        self.defaults = ud
        // Load all stored values
        // Migrate legacy "max" raw value → "max5" (Max 5× is the original Max tier).
        let planRaw = ud.string(forKey: "plan") ?? ""
        plan = Plan(rawValue: planRaw == "max" ? "max5" : planRaw) ?? .pro
        primarySurface     = Surface(rawValue: ud.string(forKey: "primarySurface") ?? "") ?? .desktop
        operatingMode      = OperatingMode(rawValue: ud.string(forKey: "operatingMode") ?? "") ?? .limitRisk
        workloadProfile    = WorkloadProfile(rawValue: ud.string(forKey: "workloadProfile") ?? "") ?? .standardWriting
        let storedInterval = ud.integer(forKey: "refreshIntervalSeconds")
        refreshIntervalSeconds = storedInterval == 0 ? 300 : storedInterval
        telemetryEnabled   = ud.bool(forKey: "telemetryEnabled")
        notificationsEnabled = ud.bool(forKey: "notificationsEnabled")
        localAPIEnabled    = ud.bool(forKey: "localAPIEnabled")
        onboardingComplete = ud.bool(forKey: "onboardingComplete")

        if let data = ud.data(forKey: "holidayRegions"),
           let regions = try? JSONDecoder().decode([HolidayRegion].self, from: data) {
            holidayRegions = regions
        } else {
            holidayRegions = [.us]
        }

        if let data = ud.data(forKey: "customPlan"),
           let custom = try? JSONDecoder().decode(CustomPlanSettings.self, from: data) {
            customPlan = custom
        } else {
            customPlan = CustomPlanSettings()
        }

        selectedModel = ClaudeModel(rawValue: ud.string(forKey: "selectedModel") ?? "") ?? .sonnet

        let storedTZ = ud.string(forKey: "forecastTimeZoneID") ?? ""
        if !storedTZ.isEmpty, TimeZone(identifier: storedTZ) != nil {
            forecastTimeZoneID = storedTZ
        } else {
            forecastTimeZoneID = TimeZone.current.identifier
        }
    }

    @Published var plan: Plan {
        didSet { defaults.set(plan.rawValue, forKey: "plan") }
    }
    @Published var primarySurface: Surface {
        didSet { defaults.set(primarySurface.rawValue, forKey: "primarySurface") }
    }
    @Published var operatingMode: OperatingMode {
        didSet { defaults.set(operatingMode.rawValue, forKey: "operatingMode") }
    }
    @Published var workloadProfile: WorkloadProfile {
        didSet { defaults.set(workloadProfile.rawValue, forKey: "workloadProfile") }
    }
    @Published var refreshIntervalSeconds: Int {
        didSet { defaults.set(refreshIntervalSeconds, forKey: "refreshIntervalSeconds") }
    }
    @Published var holidayRegions: [HolidayRegion] {
        didSet {
            if let data = try? JSONEncoder().encode(holidayRegions) {
                defaults.set(data, forKey: "holidayRegions")
            }
        }
    }
    @Published var telemetryEnabled: Bool {
        didSet { defaults.set(telemetryEnabled, forKey: "telemetryEnabled") }
    }
    @Published var notificationsEnabled: Bool {
        didSet { defaults.set(notificationsEnabled, forKey: "notificationsEnabled") }
    }
    @Published var localAPIEnabled: Bool {
        didSet { defaults.set(localAPIEnabled, forKey: "localAPIEnabled") }
    }
    @Published var onboardingComplete: Bool {
        didSet { defaults.set(onboardingComplete, forKey: "onboardingComplete") }
    }
    @Published var customPlan: CustomPlanSettings {
        didSet {
            if let data = try? JSONEncoder().encode(customPlan) {
                defaults.set(data, forKey: "customPlan")
            }
        }
    }
    @Published var selectedModel: ClaudeModel {
        didSet { defaults.set(selectedModel.rawValue, forKey: "selectedModel") }
    }
    @Published var forecastTimeZoneID: String {
        didSet { defaults.set(forecastTimeZoneID, forKey: "forecastTimeZoneID") }
    }

    /// Resolved TimeZone, falling back to the system zone if the stored ID is invalid.
    var forecastTimeZone: TimeZone {
        TimeZone(identifier: forecastTimeZoneID) ?? .current
    }
}
