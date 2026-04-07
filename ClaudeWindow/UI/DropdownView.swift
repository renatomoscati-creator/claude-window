import SwiftUI

struct DropdownView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerSection
            Divider()
            surfacesSection
            Divider()
            capacitySection
            Divider()
            reasonsSection
            Divider()
            bestWindowSection
            Divider()
            actionsSection
        }
        .padding(12)
        .frame(width: 300)
    }

    // MARK: — Sections

    private var headerSection: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(appState.primaryScore?.state.displayLabel ?? "Checking...")
                        .font(.headline)
                    Text(appState.settings.selectedModel.displayName)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Color.secondary.opacity(0.15), in: Capsule())
                }
                HStack(spacing: 4) {
                    Text("Score: \(appState.primaryScore.map { "\($0.score)" } ?? "—")")
                        .font(.caption)
                    Text("·").foregroundStyle(.secondary)
                    Text("Confidence: \(appState.primaryScore?.confidence.rawValue.capitalized ?? "—")")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
            modelAndModeToggle
        }
        .padding(.bottom, 8)
    }

    private var modelAndModeToggle: some View {
        VStack(spacing: 4) {
            Picker("", selection: Binding(
                get: { appState.settings.selectedModel },
                set: { appState.settings.selectedModel = $0 }
            )) {
                ForEach(ClaudeModel.allCases, id: \.self) {
                    Text($0.displayName).tag($0)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            Picker("", selection: Binding(
                get: { appState.settings.operatingMode },
                set: { appState.settings.operatingMode = $0 }
            )) {
                ForEach(OperatingMode.allCases, id: \.self) { mode in
                    Text(mode.displayName).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
        }
    }

    private var surfacesSection: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Surfaces")
                .font(.caption2).foregroundStyle(.secondary).padding(.bottom, 2)
            ForEach(Surface.allCases) { surface in
                SurfaceSectionView(
                    surface: surface,
                    effScore: appState.efficiencyScores[surface],
                    relScore: appState.reliabilityScores[surface],
                    activeMode: appState.settings.operatingMode
                )
            }
        }
        .padding(.vertical, 8)
    }

    private var capacitySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Estimated Capacity")
                    .font(.caption2).foregroundStyle(.secondary)
                Spacer()
                if let cap = appState.capacity {
                    Text(cap.model.displayName)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.15), in: Capsule())
                }
            }

            if let cap = appState.capacity {
                // Queries Spectrum
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Label("Queries", systemImage: "bubble.left.and.bubble.right")
                            .font(.caption)
                            .foregroundStyle(.primary)
                        Spacer()
                        Text("\(cap.minQueries)–\(cap.maxQueries)")
                            .font(.caption.bold())
                            .foregroundStyle(.primary)
                    }
                    SpectrumBar(
                        minValue: cap.minQueries,
                        maxValue: cap.maxQueries,
                        maxPossible: cap.maxQueries,
                        metricType: .queries
                    )
                }

                // Tokens Spectrum
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Label("Tokens", systemImage: "character.cursor.ibeam")
                            .font(.caption)
                            .foregroundStyle(.primary)
                        Spacer()
                        Text(formatTokens(cap.minTokens, cap.maxTokens))
                            .font(.caption.bold())
                            .foregroundStyle(.primary)
                    }
                    SpectrumBar(
                        minValue: cap.minTokens,
                        maxValue: cap.maxTokens,
                        maxPossible: cap.maxTokens,
                        metricType: .tokens
                    )
                }
            } else {
                HStack {
                    ProgressView().scaleEffect(0.7)
                    Text("Calculating capacity...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 8)
    }

    private var reasonsSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Why").font(.caption2).foregroundStyle(.secondary)
            if let reasons = appState.primaryScore?.reasons {
                ForEach(reasons, id: \.self) { reason in
                    Label(reason, systemImage: "info.circle")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 8)
    }

    private var bestWindowSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Best Next Window").font(.caption2).foregroundStyle(.secondary)
            if let bw = appState.bestWindow {
                Text("\(hourLabel(bw.startHour))–\(hourLabel(bw.endHour)) UTC · \(bw.confidence.rawValue.capitalized) confidence")
                    .font(.caption)
            } else {
                Text("Current window is already favorable")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 8)
    }

    private var actionsSection: some View {
        HStack {
            Button(action: { Task { await appState.refresh() } }) {
                Label("Refresh", systemImage: "arrow.clockwise").font(.caption)
            }
            .buttonStyle(.plain).disabled(appState.isRefreshing)
            Spacer()
            if #available(macOS 14.0, *) {
                SettingsLink {
                    Label("Settings", systemImage: "gear").font(.caption)
                }
            } else {
                Button(action: openSettings) {
                    Label("Settings", systemImage: "gear").font(.caption)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.top, 8)
    }

    // MARK: — Helpers

    private func openSettings() {
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
    }

    private func formatTokens(_ min: Int, _ max: Int) -> String {
        if max >= 1_000_000 {
            return "\(formatM(min))–\(formatM(max)) tokens"
        }
        return "\(formatK(min))–\(formatK(max)) tokens"
    }

    private func formatK(_ n: Int) -> String {
        n >= 1000 ? "\(n / 1000)K" : "\(n)"
    }

    private func formatM(_ n: Int) -> String {
        "\(n / 1_000_000)M"
    }

    private func hourLabel(_ hour: Int) -> String {
        let h = hour % 12 == 0 ? 12 : hour % 12
        return "\(h)\(hour < 12 ? "am" : "pm")"
    }
}
