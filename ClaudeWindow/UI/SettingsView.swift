import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        TabView {
            generalTab.tabItem { Label("General", systemImage: "gearshape") }
            advancedTab.tabItem { Label("Advanced", systemImage: "slider.horizontal.3") }
        }
        .frame(width: 420, height: 340)
    }

    private var generalTab: some View {
        Form {
            Picker("Claude Plan", selection: Binding(
                get: { appState.settings.plan },
                set: { appState.settings.plan = $0 }
            )) {
                ForEach(Plan.allCases, id: \.self) { Text($0.displayName).tag($0) }
            }
            Picker("Workload Profile", selection: Binding(
                get: { appState.settings.workloadProfile },
                set: { appState.settings.workloadProfile = $0 }
            )) {
                ForEach(WorkloadProfile.allCases, id: \.self) { Text($0.displayName).tag($0) }
            }
            Picker("Primary Surface", selection: Binding(
                get: { appState.settings.primarySurface },
                set: { appState.settings.primarySurface = $0 }
            )) {
                ForEach(Surface.allCases) { Text($0.displayName).tag($0) }
            }
            Picker("Default Mode", selection: Binding(
                get: { appState.settings.operatingMode },
                set: { appState.settings.operatingMode = $0 }
            )) {
                ForEach(OperatingMode.allCases, id: \.self) { Text($0.displayName).tag($0) }
            }
            Picker("Refresh Interval", selection: Binding(
                get: { appState.settings.refreshIntervalSeconds },
                set: {
                    appState.settings.refreshIntervalSeconds = $0
                    appState.restartRefreshTimer()
                }
            )) {
                Text("1 minute").tag(60)
                Text("5 minutes").tag(300)
                Text("15 minutes").tag(900)
                Text("30 minutes").tag(1800)
            }
            Section("Holiday Regions") {
                ForEach(HolidayRegion.allCases, id: \.self) { region in
                    Toggle(region.displayName, isOn: Binding(
                        get: { appState.settings.holidayRegions.contains(region) },
                        set: { include in
                            if include { appState.settings.holidayRegions.append(region) }
                            else { appState.settings.holidayRegions.removeAll { $0 == region } }
                        }
                    ))
                }
            }
        }
        .padding()
    }

    private var advancedTab: some View {
        Form {
            Toggle("Enable local API (port 58742)", isOn: Binding(
                get: { appState.settings.localAPIEnabled },
                set: {
                    appState.settings.localAPIEnabled = $0
                    appState.updateAPIServer()
                }
            ))
            Text("Exposes /score, /recommendation, /capacity endpoints on localhost only.")
                .font(.caption).foregroundStyle(.secondary)
            Toggle("Store local session history", isOn: Binding(
                get: { appState.settings.telemetryEnabled },
                set: { appState.settings.telemetryEnabled = $0 }
            ))
            Text("Improves capacity estimates over time. Never leaves this device.")
                .font(.caption).foregroundStyle(.secondary)
            Toggle("Menu bar notifications", isOn: Binding(
                get: { appState.settings.notificationsEnabled },
                set: { appState.settings.notificationsEnabled = $0 }
            ))
            Button("Reset Onboarding") { appState.settings.onboardingComplete = false }
                .foregroundStyle(.red)
        }
        .padding()
    }
}
