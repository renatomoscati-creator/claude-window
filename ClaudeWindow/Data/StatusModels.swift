import Foundation

struct StatusSummary: Decodable {
    let status: StatusIndicator
    let components: [StatusComponent]
    let incidents: [StatusIncident]
}

struct StatusIndicator: Decodable {
    let indicator: String    // "none" | "minor" | "major" | "critical"
    let description: String
}

struct StatusComponent: Decodable {
    let id: String
    let name: String
    let status: String  // "operational" | "degraded_performance" | "partial_outage" | "major_outage"
}

struct StatusIncident: Decodable {
    let id: String
    let name: String
    let status: String  // "investigating" | "identified" | "monitoring" | "resolved"
    let impact: String  // "none" | "minor" | "major" | "critical"
    let created_at: String
}

/// Processed result passed to scorers.
struct ServiceStatus {
    let indicator: String
    let hasActiveIncident: Bool
    let degradedComponentCount: Int
    let recentIncidentCount: Int
    let fetchedAt: Date
}
