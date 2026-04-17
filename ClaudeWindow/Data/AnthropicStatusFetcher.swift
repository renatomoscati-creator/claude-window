import Foundation

actor AnthropicStatusFetcher {

    // Anthropic moved the public statuspage from status.anthropic.com to
    // status.claude.com — the old host now returns a 302 redirect that
    // intermittently fails JSON decode and leaves us in "unknown" state.
    private static let url = URL(string: "https://status.claude.com/api/v2/summary.json")!
    private var cached: ServiceStatus?
    private var cachedAt: Date?

    /// Returns cached status if < 5 minutes old, otherwise fetches fresh.
    func status(maxAge: TimeInterval = 300) async -> ServiceStatus {
        if let cached, let cachedAt, Date().timeIntervalSince(cachedAt) < maxAge {
            return cached
        }
        do {
            var request = URLRequest(url: Self.url)
            request.timeoutInterval = 10
            let (data, _) = try await URLSession.shared.data(for: request)
            let summary = try JSONDecoder().decode(StatusSummary.self, from: data)
            let result = Self.process(summary)
            self.cached = result
            self.cachedAt = Date()
            return result
        } catch {
            return ServiceStatus(
                indicator: "unknown",
                hasActiveIncident: false,
                degradedComponentCount: 0,
                recentIncidentCount: 0,
                fetchedAt: Date()
            )
        }
    }

    private static func process(_ summary: StatusSummary) -> ServiceStatus {
        let activeIncidents = summary.incidents.filter { $0.status != "resolved" }
        let degraded = summary.components.filter { $0.status != "operational" }
        return ServiceStatus(
            indicator: summary.status.indicator,
            hasActiveIncident: !activeIncidents.isEmpty,
            degradedComponentCount: degraded.count,
            recentIncidentCount: activeIncidents.count,
            fetchedAt: Date()
        )
    }
}
