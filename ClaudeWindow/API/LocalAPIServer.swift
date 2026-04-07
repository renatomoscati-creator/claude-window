import Foundation
import Network

/// Minimal HTTP/1.1 server on localhost:58742.
final class LocalAPIServer {

    static let port: UInt16 = 58742
    private var listener: NWListener?
    private weak var appState: AppState?

    func start(appState: AppState) {
        guard listener == nil else { return }   // already running
        self.appState = appState

        let params = NWParameters.tcp
        params.allowLocalEndpointReuse = true
        // Restrict to loopback only — never bind to LAN interfaces
        params.requiredLocalEndpoint = NWEndpoint.hostPort(
            host: NWEndpoint.Host("127.0.0.1"),
            port: NWEndpoint.Port(rawValue: Self.port)!
        )

        guard let listener = try? NWListener(using: params, on: NWEndpoint.Port(rawValue: Self.port)!) else { return }

        self.listener = listener

        listener.newConnectionHandler = { [weak self] connection in
            connection.start(queue: .global(qos: .utility))
            self?.receive(on: connection)
        }
        listener.start(queue: .global(qos: .utility))
    }

    func stop() {
        listener?.cancel()
        listener = nil
    }

    // MARK: — Request handling

    private func receive(on connection: NWConnection) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 4096) {
            [weak self] data, _, _, _ in
            guard let data,
                  let request = String(data: data, encoding: .utf8) else {
                connection.cancel(); return
            }
            let (method, path) = Self.parseMethodAndPath(from: request)
            Task { @MainActor [weak self] in
                // Handle CORS preflight
                if method == "OPTIONS" {
                    self?.respondCORSPreflight(on: connection)
                    return
                }
                guard method == "GET" else {
                    self?.respond(body: APIHandlers.methodNotAllowed(), on: connection, statusCode: 405, statusMessage: "Method Not Allowed")
                    return
                }
                let body = self?.handle(path: path) ?? APIHandlers.notFound()
                self?.respond(body: body, on: connection)
            }
        }
    }

    @MainActor
    private func handle(path: String) -> Data {
        guard let appState else { return APIHandlers.notFound() }

        let surface = appState.settings.primarySurface
        let mode    = appState.settings.operatingMode
        let score   = (mode == .limitRisk
                        ? appState.efficiencyScores[surface]
                        : appState.reliabilityScores[surface])
                      ?? WindowScore(score: 50, state: .unknown,
                                     confidence: .low, reasons: [])

        switch path {
        case "/health":
            return APIHandlers.health()
        case "/score":
            return APIHandlers.score(surface: surface, mode: mode, score: score)
        case "/recommendation":
            let cap = appState.capacity
                   ?? QueryCapacity(minQueries: 0, maxQueries: 0,
                                    minTokens: 0, maxTokens: 0, confidence: .low)
            return APIHandlers.recommendation(surface: surface, mode: mode,
                                              score: score, capacity: cap)
        case "/capacity":
            let cap = appState.capacity
                   ?? QueryCapacity(minQueries: 0, maxQueries: 0,
                                    minTokens: 0, maxTokens: 0, confidence: .low)
            return APIHandlers.capacity(cap)
        case "/best-window":
            return APIHandlers.bestWindow(appState.bestWindow)
        case "/explain":
            return APIHandlers.explain(score)
        default:
            return APIHandlers.notFound()
        }
    }

    private func respond(body: Data, on connection: NWConnection, statusCode: Int = 200, statusMessage: String = "OK") {
        let header = "HTTP/1.1 \(statusCode) \(statusMessage)\r\nContent-Type: application/json\r\nContent-Length: \(body.count)\r\nAccess-Control-Allow-Origin: *\r\nConnection: close\r\n\r\n"
        var response = Data(header.utf8)
        response.append(body)
        connection.send(content: response, completion: .contentProcessed { _ in
            connection.cancel()
        })
    }

    private func respondCORSPreflight(on connection: NWConnection) {
        let header = "HTTP/1.1 204 No Content\r\nAccess-Control-Allow-Origin: *\r\nAccess-Control-Allow-Methods: GET, OPTIONS\r\nAccess-Control-Allow-Headers: Content-Type\r\nConnection: close\r\n\r\n"
        let response = Data(header.utf8)
        connection.send(content: response, completion: .contentProcessed { _ in
            connection.cancel()
        })
    }

    private static func parseMethodAndPath(from request: String) -> (method: String, path: String) {
        let lines = request.components(separatedBy: "\r\n")
        let parts = lines.first?.components(separatedBy: " ") ?? []
        guard parts.count >= 2 else { return ("GET", "/") }
        let method = parts[0]
        let path = parts[1].components(separatedBy: "?").first ?? "/"
        return (method, path)
    }
}
