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
        .frame(width: 360)
    }

    // MARK: — Sections

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Row 1: State label + score/confidence — full width, never truncated
            HStack(alignment: .firstTextBaseline) {
                Text(appState.primaryScore?.state.displayLabel ?? "Checking...")
                    .font(.headline)
                Spacer()
                if let s = appState.primaryScore {
                    Text("\(s.score)")
                        .font(.headline.monospacedDigit())
                    Text("·").foregroundStyle(.secondary).font(.caption)
                    Text(s.confidence.rawValue.capitalized)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.12), in: Capsule())
                }
            }

            // Row 2: Model picker (short names keep it compact)
            Picker("", selection: Binding(
                get: { appState.settings.selectedModel },
                set: { appState.settings.selectedModel = $0 }
            )) {
                ForEach(ClaudeModel.allCases, id: \.self) {
                    Text($0.shortName).tag($0)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            // Row 3: Mode toggle
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
        .padding(.bottom, 8)
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
            Text("Estimated Capacity")
                .font(.caption2).foregroundStyle(.secondary)

            if let cap = appState.capacity {
                let model = appState.settings.selectedModel
                let plan = appState.settings.plan
                let workload = appState.settings.workloadProfile
                let customPlan = plan == .custom ? appState.settings.customPlan : nil
                // Token ceiling: fixed per plan (model-independent).
                let tokenBudget = customPlan?.baseTokenLimit ?? plan.tokenBudget
                // Query ceiling: derived from token budget ÷ tokens-per-query.
                let maxQueries = max(1, tokenBudget / workload.tokensPerQuery(for: model))
                let maxTokens = tokenBudget

                // Queries Spectrum
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Label("Queries", systemImage: "bubble.left.and.bubble.right")
                            .font(.caption)
                            .foregroundStyle(.primary)
                        Spacer()
                        Text("\(cap.minQueries)–\(cap.maxQueries) / \(maxQueries)")
                            .font(.caption.bold())
                            .foregroundStyle(.primary)
                    }
                    SpectrumBar(
                        minValue: cap.minQueries,
                        maxValue: cap.maxQueries,
                        maxPossible: maxQueries,
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
                        Text("\(formatK(cap.minTokens))–\(formatK(cap.maxTokens)) / \(formatK(maxTokens))")
                            .font(.caption.bold())
                            .foregroundStyle(.primary)
                    }
                    SpectrumBar(
                        minValue: cap.minTokens,
                        maxValue: cap.maxTokens,
                        maxPossible: maxTokens,
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
