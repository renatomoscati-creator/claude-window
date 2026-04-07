import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject var appState: AppState
    @State private var step = 0

    var body: some View {
        VStack(spacing: 20) {
            ProgressView(value: Double(step + 1), total: 6).padding(.horizontal)
            Group {
                switch step {
                case 0: planStep
                case 1: modelStep
                case 2: surfaceStep
                case 3: workloadStep
                case 4: regionStep
                case 5: telemetryStep
                default: EmptyView()
                }
            }
            HStack {
                if step > 0 {
                    Button("Back") { step -= 1 }.buttonStyle(.plain)
                }
                Spacer()
                Button(step < 5 ? "Next" : "Get Started") {
                    if step < 5 { step += 1 }
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

    private var modelStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Which model do you use most?").font(.headline)
            VStack(alignment: .leading, spacing: 6) {
                ForEach(ClaudeModel.allCases, id: \.self) { model in
                    Button(action: { appState.settings.selectedModel = model }) {
                        HStack(spacing: 8) {
                            Image(systemName: appState.settings.selectedModel == model
                                  ? "largecircle.fill.circle" : "circle")
                                .foregroundStyle(appState.settings.selectedModel == model
                                                 ? Color.accentColor : .secondary)
                            VStack(alignment: .leading) {
                                Text(model.displayName).foregroundStyle(.primary)
                                Text(modelDescription(model)).font(.caption2).foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            Text("Affects token estimates and capacity calculations.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    private func modelDescription(_ model: ClaudeModel) -> String {
        switch model {
        case .haiku:  return "Fast, efficient — ~$0.01/query"
        case .sonnet: return "Balanced quality/cost — ~$0.03/query"
        case .opus:   return "Most capable — ~$0.08/query"
        }
    }

    private var surfaceStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Which surface do you use most?").font(.headline)
            VStack(alignment: .leading, spacing: 6) {
                ForEach(Surface.allCases) { surface in
                    Button(action: { appState.settings.primarySurface = surface }) {
                        HStack(spacing: 8) {
                            Image(systemName: appState.settings.primarySurface == surface
                                  ? "largecircle.fill.circle" : "circle")
                                .foregroundStyle(appState.settings.primarySurface == surface
                                                 ? Color.accentColor : .secondary)
                            Text(surface.displayName)
                                .foregroundStyle(.primary)
                            Spacer()
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            Text("This drives the menu bar icon color.").font(.caption).foregroundStyle(.secondary)
        }
    }

    private var workloadStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("What best describes your typical workload?").font(.headline)
            VStack(alignment: .leading, spacing: 6) {
                ForEach(WorkloadProfile.allCases, id: \.self) { profile in
                    Button(action: { appState.settings.workloadProfile = profile }) {
                        HStack(spacing: 8) {
                            Image(systemName: appState.settings.workloadProfile == profile
                                  ? "largecircle.fill.circle" : "circle")
                                .foregroundStyle(appState.settings.workloadProfile == profile
                                                 ? Color.accentColor : .secondary)
                            Text(profile.displayName)
                                .foregroundStyle(.primary)
                            Spacer()
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var regionStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Which holiday calendars should we factor in?").font(.headline)
            VStack(alignment: .leading, spacing: 6) {
                ForEach(HolidayRegion.allCases, id: \.self) { region in
                    let selected = appState.settings.holidayRegions.contains(region)
                    Button(action: {
                        if selected {
                            appState.settings.holidayRegions.removeAll { $0 == region }
                        } else {
                            appState.settings.holidayRegions.append(region)
                        }
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: selected ? "checkmark.square.fill" : "square")
                                .foregroundStyle(selected ? Color.accentColor : .secondary)
                            Text(region.displayName)
                                .foregroundStyle(.primary)
                            Spacer()
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var telemetryStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Enable local usage history?").font(.headline)
            let enabled = appState.settings.telemetryEnabled
            Button(action: { appState.settings.telemetryEnabled.toggle() }) {
                HStack(spacing: 8) {
                    Image(systemName: enabled ? "checkmark.square.fill" : "square")
                        .foregroundStyle(enabled ? Color.accentColor : .secondary)
                    Text("Store local session outcomes")
                        .foregroundStyle(.primary)
                    Spacer()
                }
            }
            .buttonStyle(.plain)
            Text("Your data never leaves this device. It helps the app calibrate estimates over time.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }
}
