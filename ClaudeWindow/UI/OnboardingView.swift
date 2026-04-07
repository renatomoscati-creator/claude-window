import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject var appState: AppState
    @State private var step = 0

    var body: some View {
        VStack(spacing: 20) {
            ProgressView(value: Double(step + 1), total: 5).padding(.horizontal)
            Group {
                switch step {
                case 0: planStep
                case 1: surfaceStep
                case 2: workloadStep
                case 3: regionStep
                case 4: telemetryStep
                default: EmptyView()
                }
            }
            HStack {
                if step > 0 {
                    Button("Back") { step -= 1 }.buttonStyle(.plain)
                }
                Spacer()
                Button(step < 4 ? "Next" : "Get Started") {
                    if step < 4 { step += 1 }
                    else { appState.settings.onboardingComplete = true }
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(.horizontal)
        }
        .padding(24)
        .frame(width: 380, height: 300)
    }

    private var planStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Which Claude plan are you on?").font(.headline)
            Picker("Plan", selection: Binding(
                get: { appState.settings.plan },
                set: { appState.settings.plan = $0 }
            )) {
                ForEach(Plan.allCases, id: \.self) { Text($0.displayName).tag($0) }
            }.pickerStyle(.segmented)
            Text("Used to estimate session capacity. Not shared with Anthropic.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    private var surfaceStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Which surface do you use most?").font(.headline)
            Picker("Surface", selection: Binding(
                get: { appState.settings.primarySurface },
                set: { appState.settings.primarySurface = $0 }
            )) {
                ForEach(Surface.allCases) { Text($0.displayName).tag($0) }
            }.pickerStyle(.radioGroup)
            Text("This drives the menu bar icon color.").font(.caption).foregroundStyle(.secondary)
        }
    }

    private var workloadStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("What best describes your typical workload?").font(.headline)
            Picker("Workload", selection: Binding(
                get: { appState.settings.workloadProfile },
                set: { appState.settings.workloadProfile = $0 }
            )) {
                ForEach(WorkloadProfile.allCases, id: \.self) { Text($0.displayName).tag($0) }
            }.pickerStyle(.radioGroup)
        }
    }

    private var regionStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Which holiday calendars should we factor in?").font(.headline)
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

    private var telemetryStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Enable local usage history?").font(.headline)
            Toggle("Store local session outcomes", isOn: Binding(
                get: { appState.settings.telemetryEnabled },
                set: { appState.settings.telemetryEnabled = $0 }
            ))
            Text("Your data never leaves this device. It helps the app calibrate estimates over time.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }
}
