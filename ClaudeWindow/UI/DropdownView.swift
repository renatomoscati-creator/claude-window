import SwiftUI

struct DropdownView: View {
    @EnvironmentObject var appState: AppState

    // Feature flag: session usage tracker (stepper, consumption bar, remaining
    // counter). Retired because the remaining-tokens counter proved too noisy
    // to be useful. Code kept intact in sessionSection below for future revival.
    private static let showSessionTracker = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerSection
            Divider()
            surfacesSection
            Divider()
            capacitySection
            if Self.showSessionTracker {
                Divider()
                sessionSection
            }
            if hasReasons {
                Divider()
                reasonsSection
            }
            Divider()
            bestWindowSection
            Divider()
            actionsSection
            disclaimerSection
        }
        .padding(12)
        .frame(width: 360)
    }

    private var disclaimerSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Usage data and window suggestions are estimates based on historical patterns and official Anthropic releases, not guaranteed numbers.")
            Text("Reliability and system status are read in real time from Anthropic's status page.")
            Text("This project is not officially affiliated with or endorsed by Anthropic.")
        }
        .font(.system(size: 9))
        .foregroundStyle(.tertiary)
        .fixedSize(horizontal: false, vertical: true)
        .padding(.top, 8)
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
                    Text("·").foregroundStyle(.tertiary).font(.system(size: 9))
                    Text("\(s.confidence.rawValue.capitalized) Confidence")
                        .font(.system(size: 9))
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal, 5).padding(.vertical, 1)
                        .background(Color.secondary.opacity(0.08), in: Capsule())
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
        }
        .padding(.bottom, 8)
    }

    private var surfacesSection: some View {
        let mode = appState.settings.operatingMode
        return VStack(alignment: .leading, spacing: 6) {
            // Heading makes it explicit: the picker below controls what these
            // three per-surface scores mean. Previously the mode picker lived
            // in the header where its scope was ambiguous.
            HStack {
                Text("Surface scores")
                    .font(.caption2).foregroundStyle(.secondary)
                Spacer()
                Text("score by")
                    .font(.system(size: 9)).foregroundStyle(.tertiary)
            }

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

            Text(mode.shortDescription)
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
                .padding(.bottom, 2)

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
                // Clamp both inputs. `customPlan?.baseTokenLimit` is already
                // sanitized by CustomPlanSettings, but plan.tokenBudget and the
                // workload multiplier can in principle be 0 for future enum cases.
                let tokenBudget = max(1, customPlan?.baseTokenLimit ?? plan.tokenBudget)
                let tokensPerQ  = max(1, workload.tokensPerQuery(for: model))

                // Per-model query ceiling: marker position = efficiency × 0.8,
                // so at score 78 both markers sit at ~62% (yellow-green zone)
                // regardless of which model is selected.
                let maxQueries = max(1, tokenBudget / tokensPerQ)

                HStack {
                    Label("Queries", systemImage: "bubble.left.and.bubble.right")
                        .font(.caption).foregroundStyle(.primary)
                    Spacer()
                    Text("\(cap.minQueries)–\(cap.maxQueries) / \(maxQueries)")
                        .font(.caption.bold()).foregroundStyle(.primary)
                }

                HStack {
                    Label("Cost/query", systemImage: "bolt")
                        .font(.caption).foregroundStyle(.primary)
                    Spacer()
                    Text("~\(formatK(tokensPerQ)) tokens")
                        .font(.caption.bold()).foregroundStyle(.primary)
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

    private var hasReasons: Bool {
        !(appState.primaryScore?.reasons.isEmpty ?? true)
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

    private var sessionSection: some View {
        let plan     = appState.settings.plan
        let model    = appState.settings.selectedModel
        let workload = appState.settings.workloadProfile
        let customPlan = plan == .custom ? appState.settings.customPlan : nil
        let tokenBudget  = max(1, customPlan?.baseTokenLimit ?? plan.tokenBudget)
        let tokensPerQ   = max(1, workload.tokensPerQuery(for: model))
        let used         = appState.queriesUsedThisWindow
        let tokensUsed   = used * tokensPerQ
        let tokensLeft   = max(0, tokenBudget - tokensUsed)
        let queriesLeft  = max(0, tokensLeft / tokensPerQ)
        let pctUsed      = min(100, Int(Double(tokensUsed) / Double(tokenBudget) * 100))
        // Consumption bar: 25% headroom so 100% usage doesn't clip the marker.
        let barCeiling   = Int(Double(tokenBudget) * 1.25)
        let windowMins   = Int((1.0 - appState.sessionWindowProgress) * 300)

        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("This Session")
                    .font(.caption2).foregroundStyle(.secondary)
                Spacer()
                Text("\(windowMins)m left in window")
                    .font(.caption2).foregroundStyle(.tertiary)
            }

            // Stepper row
            HStack {
                Label("Queries used", systemImage: "checkmark.circle")
                    .font(.caption).foregroundStyle(.primary)
                Spacer()
                HStack(spacing: 8) {
                    Button(action: { appState.decrementQuery() }) {
                        Image(systemName: "minus.circle")
                            .font(.caption)
                    }.buttonStyle(.plain).disabled(used == 0)

                    Text("\(used)")
                        .font(.caption.monospacedDigit().bold())
                        .frame(minWidth: 24, alignment: .center)

                    Button(action: { appState.incrementQuery() }) {
                        Image(systemName: "plus.circle")
                            .font(.caption)
                    }.buttonStyle(.plain)
                }
            }

            // Consumption bar (green=fresh → red=depleted)
            SpectrumBar(
                minValue: tokensUsed,
                maxValue: tokensUsed,
                maxPossible: barCeiling,
                metricType: .cost
            )

            // Remaining summary
            HStack {
                Image(systemName: tokensLeft > 0 ? "battery.75" : "battery.0")
                    .font(.caption2)
                    .foregroundStyle(tokensLeft > tokenBudget / 3 ? .green : tokensLeft > 0 ? .orange : .red)
                Text(tokensLeft > 0
                     ? "~\(formatK(tokensLeft)) tokens · ~\(queriesLeft) queries remaining"
                     : "Budget likely exhausted for this window")
                    .font(.caption2)
                    .foregroundStyle(tokensLeft > 0 ? Color.secondary : Color.red)
                Spacer()
                Text("\(pctUsed)% used")
                    .font(.caption2).foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 8)
    }

    private var bestWindowSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Best Next Window").font(.caption2).foregroundStyle(.secondary)

            if let bw = appState.bestWindow {
                Text("\(hourLabel(bw.startHour))–\(hourLabel(bw.endHour)) UTC · \(bw.confidence.rawValue.capitalized) confidence")
                    .font(.caption)
            } else {
                Text("Current window is already favorable")
                    .font(.caption).foregroundStyle(.secondary)
            }

            TimelineView(.everyMinute) { context in
                ForecastStrip(
                    now: context.date,
                    regions: Set(appState.settings.holidayRegions),
                    timeZone: appState.settings.forecastTimeZone
                )
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
                SettingsButtonMacOS14()
            } else {
                Button(action: openSettingsFallback) {
                    Label("Settings", systemImage: "gear").font(.caption)
                }
                .buttonStyle(.plain)
            }
            Divider().frame(height: 12).padding(.horizontal, 4)
            Button(action: { NSApp.terminate(nil) }) {
                Label("Quit", systemImage: "power").font(.caption)
            }
            .buttonStyle(.plain)
        }
        .padding(.top, 8)
    }

    // MARK: — Helpers

    private func openSettingsFallback() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        bringSettingsWindowToFront()
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

@available(macOS 14.0, *)
private struct SettingsButtonMacOS14: View {
    @Environment(\.openSettings) private var openSettings
    var body: some View {
        Button(action: {
            NSApp.activate(ignoringOtherApps: true)
            openSettings()
            bringSettingsWindowToFront()
        }) {
            Label("Settings", systemImage: "gear").font(.caption)
        }
        .buttonStyle(.plain)
    }
}

// Menu-bar apps (LSUIElement) open Settings behind other windows by default.
// Activating the app isn't enough — the panel needs an explicit orderFront
// on the next runloop tick once SwiftUI has created the window.
private func bringSettingsWindowToFront() {
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
        for window in NSApp.windows where window.isVisible {
            let id = window.identifier?.rawValue ?? ""
            let title = window.title
            if id.contains("Settings") || id.contains("com_apple_SwiftUI_Settings") || title == "Settings" {
                window.level = .floating
                window.orderFrontRegardless()
                window.makeKeyAndOrderFront(nil)
                // Drop back to normal level so it doesn't stay pinned above everything.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    window.level = .normal
                }
            }
        }
    }
}

// MARK: - Forecast strip

/// 12-hour pressure forecast bar. Each bar = one hour; color encodes predicted
/// pressure (green=low/favorable, red=high/congested). Hour labels render in
/// the user-selected forecast timezone.
private struct ForecastStrip: View {
    let now: Date
    let regions: Set<HolidayRegion>
    let timeZone: TimeZone

    private struct Slot: Identifiable {
        let id: Int
        let hour: Int   // hour-of-day in the configured timezone
        let pressure: Double
    }

    private var slots: [Slot] {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = timeZone
        return (0..<12).compactMap { offset in
            guard let t = cal.date(byAdding: .hour, value: offset, to: now) else { return nil }
            let h = cal.component(.hour, from: t)
            let p = TimingHeuristics.pressureScore(at: t, holidayRegions: regions)
            return Slot(id: offset, hour: h, pressure: p)
        }
    }

    var body: some View {
        let data = slots
        let bestIdx = data.indices.min(by: { data[$0].pressure < data[$1].pressure }) ?? 0

        VStack(alignment: .leading, spacing: 4) {
            // Timezone caption so there is no ambiguity about what the bars mean.
            Text("Times in \(TimeZoneFormatting.abbrAndOffset(for: timeZone))")
                .font(.system(size: 9))
                .foregroundStyle(.secondary)

            HStack(alignment: .bottom, spacing: 2) {
                ForEach(data) { slot in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(color(for: slot.pressure))
                        .frame(height: barHeight(for: slot.pressure))
                        .frame(maxWidth: .infinity)
                        .overlay(alignment: .top) {
                            if slot.id == bestIdx {
                                Image(systemName: "star.fill")
                                    .font(.system(size: 7))
                                    .foregroundStyle(.yellow)
                                    .offset(y: -9)
                            }
                        }
                        .help("\(hourLabel(slot.hour)) · \(pressureLabel(slot.pressure))")
                }
            }
            .frame(height: 34, alignment: .bottom)

            // Tick labels at +0h / +4h / +8h / +12h.
            HStack {
                tickLabel(for: data.first?.hour)
                Spacer()
                tickLabel(for: data[safe: 4]?.hour)
                Spacer()
                tickLabel(for: data[safe: 8]?.hour)
                Spacer()
                tickLabel(for: data.last.map { ($0.hour + 1) % 24 })
            }
            .font(.system(size: 9))
            .foregroundStyle(.tertiary)

            HStack(spacing: 8) {
                legendSwatch(.green, "efficient")
                legendSwatch(.yellow, "average")
                legendSwatch(.orange, "high risk")
                legendSwatch(.red, "poor")
            }
            .font(.system(size: 9))
            .foregroundStyle(.secondary)
        }
    }

    private func tickLabel(for hour: Int?) -> some View {
        Text(hour.map { hourLabel($0) } ?? "")
    }

    private func legendSwatch(_ color: Color, _ text: String) -> some View {
        HStack(spacing: 3) {
            RoundedRectangle(cornerRadius: 1).fill(color).frame(width: 8, height: 6)
            Text(text)
        }
    }

    /// Use the same mapping LimitEfficiencyScorer applies so a given pressure
    /// paints the same color here as the main app score state. See
    /// LimitEfficiencyScorer.score — `rawScore = (1 − pressure) × 85 + 15`,
    /// thresholds 70/40/22 → efficient/average/highRisk/poor.
    private func rawScore(for p: Double) -> Double {
        (1.0 - p) * 85.0 + 15.0
    }

    private func color(for p: Double) -> Color {
        let s = rawScore(for: p)
        switch s {
        case 70...:    return .green    // efficient
        case 40..<70:  return .yellow   // average
        case 22..<40:  return .orange   // high risk
        default:       return .red      // poor
        }
    }

    private func barHeight(for p: Double) -> CGFloat {
        10 + CGFloat(p) * 24
    }

    private func hourLabel(_ hour: Int) -> String {
        let h = hour % 12 == 0 ? 12 : hour % 12
        let suffix = hour < 12 ? "AM" : "PM"
        return "\(h)\(suffix)"
    }

    private func pressureLabel(_ p: Double) -> String {
        let s = rawScore(for: p)
        switch s {
        case 70...:    return "efficient"
        case 40..<70:  return "average"
        case 22..<40:  return "high risk"
        default:       return "poor"
        }
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
