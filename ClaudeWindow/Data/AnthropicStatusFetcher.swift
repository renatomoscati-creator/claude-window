import Foundation

actor AnthropicStatusFetcher {

    private static let url = URL(string: "https://status.anthropic.com/api/v2/summary.json")!
    private var cached: ServiceStatus?
    private var cachedAt: Date?

    /// Returns cached status if < 5 minutes old, otherwise fetches fresh.
    func status(maxAge: TimeInterval = 300) async -> ServiceStatus {
        if let cached, let cachedAt, Date().timeIntervalSince(cachedAt) < maxAge {
            return cached
        }
        do {
            let (data, _) = try await URLSession.shared.data(from: Self.url)
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
