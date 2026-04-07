import Foundation
import SwiftUI

@MainActor
final class AppState: ObservableObject {

    // MARK: — Dependencies
    let settings: SettingsStore
    let telemetry: TelemetryStore
    private let statusFetcher = AnthropicStatusFetcher()

    // MARK: — Published state
    @Published var primaryScore: WindowScore?
    @Published var efficiencyScores: [Surface: WindowScore] = [:]
    @Published var reliabilityScores: [Surface: WindowScore] = [:]
    @Published var capacity: QueryCapacity?
    @Published var bestWindow: BestWindow?
    @Published var isRefreshing = false
    @Published var lastRefreshed: Date?

    private var refreshTask: Task<Void, Never>?
    private let apiServer = LocalAPIServer()

    init(settings: SettingsStore = SettingsStore(), telemetry: TelemetryStore = TelemetryStore()) {
        self.settings = settings
        self.telemetry = telemetry
        Task { await refresh() }
        startRefreshTimer()
        if settings.localAPIEnabled {
            apiServer.start(appState: self)
        }
    }

    // MARK: — Refresh

    func refresh() async {
        isRefreshing = true
        defer { isRefreshing = false }

        let serviceStatus = await statusFetcher.status()
        let holidayRegions = Set(settings.holidayRegions)
        let now = Date()

        for surface in Surface.allCases {
            let eff = LimitEfficiencyScorer.score(
                at: now, serviceStatus: serviceStatus, holidayRegions: holidayRegions
            )
            let rel = ReliabilityScorer.score(serviceStatus: serviceStatus)
            efficiencyScores[surface] = eff
            reliabilityScores[surface] = rel
        }

        let primary = settings.primarySurface
        let mode    = settings.operatingMode
        let activeScore = mode == .limitRisk
            ? efficiencyScores[primary]!
            : reliabilityScores[primary]!

        let effScore = efficiencyScores[primary]!
        let relScore = reliabilityScores[primary]!
        let conf = ConfidenceEstimator.estimate(
            serviceStatus: serviceStatus,
            hasUserHistory: telemetry.hasHistory,
            efficiencyScore: effScore.score,
            reliabilityScore: relScore.score
        )

        primaryScore = WindowScore(
            score: activeScore.score,
            state: activeScore.state,
            confidence: conf,
            reasons: activeScore.reasons
        )

        let customPlan = settings.plan == .custom ? settings.customPlan : nil
        capacity = CapacityEstimator.estimate(
            efficiencyScore: effScore.score,
            plan: settings.plan,
            workload: settings.workloadProfile,
            confidence: conf,
            customPlan: customPlan
        )

        bestWindow = BestWindowBuilder.build(
            from: now, lookAheadHours: 24, holidayRegions: holidayRegions
        )

        lastRefreshed = Date()
    }

    // MARK: — Timer

    func startRefreshTimer() {
        refreshTask?.cancel()
        refreshTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                let interval = Double(self.settings.refreshIntervalSeconds)
                try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
                await self.refresh()
            }
        }
    }

    func restartRefreshTimer() {
        startRefreshTimer()
    }

    func updateAPIServer() {
        if settings.localAPIEnabled {
            apiServer.start(appState: self)
        } else {
            apiServer.stop()
        }
    }
}
