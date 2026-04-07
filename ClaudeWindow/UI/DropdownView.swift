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
                Text(appState.primaryScore?.state.displayLabel ?? "Checking...")
                    .font(.headline)
                HStack(spacing: 4) {
                    Text("Score: \(appState.primaryScore.map { "\($0.score)" } ?? "—")")
                        .font(.caption)
                    Text("·").foregroundStyle(.secondary)
                    Text("Confidence: \(appState.primaryScore?.confidence.rawValue.capitalized ?? "—")")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
            modeToggle
        }
        .padding(.bottom, 8)
    }

    private var modeToggle: some View {
        Picker("", selection: Binding(
            get: { appState.settings.operatingMode },
            set: { appState.settings.operatingMode = $0 }
        )) {
            ForEach(OperatingMode.allCases, id: \.self) { mode in
                Text(mode.displayName).tag(mode)
            }
        }
        .pickerStyle(.segmented)
        .frame(width: 130)
        .labelsHidden()
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
        VStack(alignment: .leading, spacing: 4) {
            Text("Estimated Capacity")
                .font(.caption2).foregroundStyle(.secondary)
            if let cap = appState.capacity {
                Label("\(cap.minQueries)–\(cap.maxQueries) queries",
                      systemImage: "bubble.left.and.bubble.right").font(.caption)
                Label(formatTokens(cap.minTokens, cap.maxTokens),
                      systemImage: "character.cursor.ibeam").font(.caption)
            } else {
                Text("—").font(.caption).foregroundStyle(.secondary)
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
                Text("\(hourLabel(bw.startHour))–\(hourLabel(bw.endHour)) local · \(bw.confidence.rawValue.capitalized) confidence")
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
        "\(formatK(min))–\(formatK(max)) tokens"
    }

    private func formatK(_ n: Int) -> String {
        n >= 1000 ? "\(n / 1000)K" : "\(n)"
    }

    private func hourLabel(_ hour: Int) -> String {
        let h = hour % 12 == 0 ? 12 : hour % 12
        return "\(h)\(hour < 12 ? "am" : "pm")"
    }
}
