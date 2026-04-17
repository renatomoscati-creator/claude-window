import Foundation

enum APIHandlers {

    // MARK: — Typed response payloads

    private struct HealthResponse: Encodable {
        let status: String
        let timestamp: String
    }

    private struct ScoreResponse: Encodable {
        let surface: String
        let mode: String
        let window_score: Int
        let state: String
        let confidence: String
    }

    private struct RecommendationResponse: Encodable {
        let surface: String
        let mode: String
        let model: String
        let window_score: Int
        let state: String
        let estimated_queries_min: Int
        let estimated_queries_max: Int
        let estimated_tokens_min: Int
        let estimated_tokens_max: Int
        let confidence: String
        let reasons: [String]
    }

    private struct CapacityResponse: Encodable {
        let model: String
        let estimated_queries_min: Int
        let estimated_queries_max: Int
        let estimated_tokens_min: Int
        let estimated_tokens_max: Int
        let confidence: String
    }

    private struct BestWindowResponse: Encodable {
        let start_hour_utc: Int?
        let end_hour_utc: Int?
        let confidence: String?
        let reasons: [String]?
        let best_window: Bool?   // nil-flag sentinel when no window available
    }

    private struct ExplainResponse: Encodable {
        let score: Int
        let state: String
        let confidence: String
        let reasons: [String]
    }

    private struct ErrorResponse: Encodable {
        let error: String
    }

    // MARK: — Handlers

    static func health() -> Data {
        encode(HealthResponse(
            status: "ok",
            timestamp: ISO8601DateFormatter().string(from: Date())
        ))
    }

    static func score(surface: Surface, mode: OperatingMode, score: WindowScore) -> Data {
        encode(ScoreResponse(
            surface: surface.rawValue,
            mode: mode.rawValue,
            window_score: score.score,
            state: score.state.rawValue,
            confidence: score.confidence.rawValue
        ))
    }

    static func recommendation(surface: Surface, mode: OperatingMode,
                                score: WindowScore, capacity: QueryCapacity) -> Data {
        encode(RecommendationResponse(
            surface: surface.rawValue,
            mode: mode.rawValue,
            model: capacity.model.rawValue,
            window_score: score.score,
            state: score.state.rawValue,
            estimated_queries_min: capacity.minQueries,
            estimated_queries_max: capacity.maxQueries,
            estimated_tokens_min: capacity.minTokens,
            estimated_tokens_max: capacity.maxTokens,
            confidence: score.confidence.rawValue,
            reasons: score.reasons
        ))
    }

    static func capacity(_ cap: QueryCapacity) -> Data {
        encode(CapacityResponse(
            model: cap.model.rawValue,
            estimated_queries_min: cap.minQueries,
            estimated_queries_max: cap.maxQueries,
            estimated_tokens_min: cap.minTokens,
            estimated_tokens_max: cap.maxTokens,
            confidence: cap.confidence.rawValue
        ))
    }

    static func bestWindow(_ bw: BestWindow?) -> Data {
        guard let bw else {
            return encode(BestWindowResponse(
                start_hour_utc: nil, end_hour_utc: nil,
                confidence: nil, reasons: nil, best_window: false
            ))
        }
        return encode(BestWindowResponse(
            start_hour_utc: bw.startHour,
            end_hour_utc: bw.endHour,
            confidence: bw.confidence.rawValue,
            reasons: bw.reasons,
            best_window: nil
        ))
    }

    static func explain(_ score: WindowScore) -> Data {
        encode(ExplainResponse(
            score: score.score,
            state: score.state.rawValue,
            confidence: score.confidence.rawValue,
            reasons: score.reasons
        ))
    }

    static func notFound() -> Data {
        encode(ErrorResponse(error: "not found"))
    }

    static func methodNotAllowed() -> Data {
        encode(ErrorResponse(error: "method not allowed, use GET"))
    }

    // MARK: — Helper

    private static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.outputFormatting = [.sortedKeys]
        e.dateEncodingStrategy = .iso8601
        return e
    }()

    static func encode<T: Encodable>(_ value: T) -> Data {
        (try? encoder.encode(value)) ?? Data("{}".utf8)
    }
}
