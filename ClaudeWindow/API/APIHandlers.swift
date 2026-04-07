import Foundation

enum APIHandlers {

    static func health() -> Data {
        encode(["status": "ok",
                "timestamp": ISO8601DateFormatter().string(from: Date())])
    }

    static func score(surface: Surface, mode: OperatingMode, score: WindowScore) -> Data {
        encode([
            "surface":      surface.rawValue,
            "mode":         mode.rawValue,
            "window_score": score.score,
            "state":        score.state.rawValue,
            "confidence":   score.confidence.rawValue
        ] as [String: Any])
    }

    static func recommendation(surface: Surface, mode: OperatingMode,
                                score: WindowScore, capacity: QueryCapacity) -> Data {
        encode([
            "surface":               surface.rawValue,
            "mode":                  mode.rawValue,
            "window_score":          score.score,
            "state":                 score.state.rawValue,
            "estimated_queries_min": capacity.minQueries,
            "estimated_queries_max": capacity.maxQueries,
            "estimated_tokens_min":  capacity.minTokens,
            "estimated_tokens_max":  capacity.maxTokens,
            "confidence":            score.confidence.rawValue,
            "reasons":               score.reasons
        ] as [String: Any])
    }

    static func capacity(_ cap: QueryCapacity) -> Data {
        encode([
            "estimated_queries_min": cap.minQueries,
            "estimated_queries_max": cap.maxQueries,
            "estimated_tokens_min":  cap.minTokens,
            "estimated_tokens_max":  cap.maxTokens,
            "confidence":            cap.confidence.rawValue
        ] as [String: Any])
    }

    static func bestWindow(_ bw: BestWindow?) -> Data {
        guard let bw else { return encode(["best_window": NSNull()]) }
        return encode([
            "start_hour_utc": bw.startHour,
            "end_hour_utc":   bw.endHour,
            "confidence":     bw.confidence.rawValue,
            "reasons":        bw.reasons
        ] as [String: Any])
    }

    static func explain(_ score: WindowScore) -> Data {
        encode([
            "score":      score.score,
            "state":      score.state.rawValue,
            "confidence": score.confidence.rawValue,
            "reasons":    score.reasons
        ] as [String: Any])
    }

    static func notFound() -> Data {
        encode(["error": "not found"])
    }

    static func methodNotAllowed() -> Data {
        encode(["error": "method not allowed, use GET"])
    }

    // MARK: — Helper

    static func encode(_ dict: [String: Any]) -> Data {
        (try? JSONSerialization.data(withJSONObject: dict, options: [.sortedKeys])) ?? Data()
    }
}
