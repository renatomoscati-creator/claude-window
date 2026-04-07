import XCTest
@testable import ClaudeWindow

final class StatusParserTests: XCTestCase {

    private let sampleJSON = """
    {
      "status": { "indicator": "minor", "description": "Minor Service Disruption" },
      "components": [
        { "id": "1", "name": "Claude.ai", "status": "operational" },
        { "id": "2", "name": "Claude API", "status": "degraded_performance" }
      ],
      "incidents": [
        {
          "id": "inc1",
          "name": "Elevated error rates",
          "status": "investigating",
          "impact": "minor",
          "created_at": "2026-04-07T10:00:00.000Z"
        }
      ]
    }
    """.data(using: .utf8)!

    func test_parse_overallIndicator() throws {
        let summary = try JSONDecoder().decode(StatusSummary.self, from: sampleJSON)
        XCTAssertEqual(summary.status.indicator, "minor")
    }

    func test_parse_componentCount() throws {
        let summary = try JSONDecoder().decode(StatusSummary.self, from: sampleJSON)
        XCTAssertEqual(summary.components.count, 2)
    }

    func test_parse_degradedComponent() throws {
        let summary = try JSONDecoder().decode(StatusSummary.self, from: sampleJSON)
        let degraded = summary.components.filter { $0.status != "operational" }
        XCTAssertEqual(degraded.count, 1)
        XCTAssertEqual(degraded[0].name, "Claude API")
    }

    func test_parse_incidentCount() throws {
        let summary = try JSONDecoder().decode(StatusSummary.self, from: sampleJSON)
        XCTAssertEqual(summary.incidents.count, 1)
        XCTAssertEqual(summary.incidents[0].impact, "minor")
    }
}
