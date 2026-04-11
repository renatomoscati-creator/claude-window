import Foundation
import SwiftUI
import Combine

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

    // MARK: — Session usage tracker
    // Tracks queries used in the current 5-hour rolling window.
    // Persisted across app restarts; auto-resets when the window expires.
    static let windowDuration: TimeInterval = 5 * 3600  // 5 hours

    @Published var queriesUsedThisWindow: Int = 0
    @Published var sessionWindowStart: Date = Date()

    private var refreshTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()
    private let apiServer = LocalAPIServer()

    init(settings: SettingsStore = SettingsStore(), telemetry: TelemetryStore = TelemetryStore()) {
        self.settings = settings
        self.telemetry = telemetry
        loadSessionState()
        Task { await refresh() }
        startRefreshTimer()
        if settings.localAPIEnabled {
            apiServer.start(appState: self)
        }
        setupBindings()
    }

    // MARK: — Session tracking

    private func loadSessionState() {
        let ud = UserDefaults(suiteName: "com.claudewindow.app") ?? .standard
        let start = ud.object(forKey: "sessionWindowStart") as? Date ?? Date()
        let expired = Date().timeIntervalSince(start) >= Self.windowDuration
        if expired {
            sessionWindowStart = Date()
            queriesUsedThisWindow = 0
            saveSessionState()
        } else {
            sessionWindowStart = start
            queriesUsedThisWindow = ud.integer(forKey: "queriesUsedThisWindow")
        }
    }

    private func saveSessionState() {
        let ud = UserDefaults(suiteName: "com.claudewindow.app") ?? .standard
        ud.set(queriesUsedThisWindow, forKey: "queriesUsedThisWindow")
        ud.set(sessionWindowStart,    forKey: "sessionWindowStart")
    }

    func incrementQuery() {
        checkWindowExpiry()
        queriesUsedThisWindow += 1
        saveSessionState()
    }

    func decrementQuery() {
        checkWindowExpiry()
        queriesUsedThisWindow = max(0, queriesUsedThisWindow - 1)
        saveSessionState()
    }

    func resetSession() {
        sessionWindowStart = Date()
        queriesUsedThisWindow = 0
        saveSessionState()
    }

    private func checkWindowExpiry() {
        if Date().timeIntervalSince(sessionWindowStart) >= Self.windowDuration {
            sessionWindowStart = Date()
            queriesUsedThisWindow = 0
        }
    }

    var sessionWindowProgress: Double {
        min(1.0, Date().timeIntervalSince(sessionWindowStart) / Self.windowDuration)
    }

    // MARK: — Bindings

    private func setupBindings() {
        // Auto-refresh when model changes (capacity estimates change)
        settings.$selectedModel
            .dropFirst()
            .sink { [weak self] _ in
                Task { await self?.refresh() }
            }
            .store(in: &cancellables)
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

        guard let effScore = efficiencyScores[primary],
              let relScore = reliabilityScores[primary] else {
            // Scores haven't been computed yet — early exit
            isRefreshing = false
            return
        }

        let activeScore = mode == .limitRisk ? effScore : relScore
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
            model: settings.selectedModel,
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
