import Foundation
import Network

/// Minimal HTTP/1.1 server on localhost:58742.
final class LocalAPIServer {

    static let port: UInt16 = 58742
    /// Max header size we accept before 431'ing. Prevents unbounded buffering.
    private static let maxRequestBytes = 16 * 1024
    private static let endpointPort = NWEndpoint.Port(rawValue: port) ?? .any

    private var listener: NWListener?
    private weak var appState: AppState?
    private(set) var lastStartError: String?

    func start(appState: AppState) {
        guard listener == nil else { return }   // already running
        self.appState = appState
        self.lastStartError = nil

        let params = NWParameters.tcp
        params.allowLocalEndpointReuse = true
        // Restrict to loopback only — never bind to LAN interfaces
        params.requiredLocalEndpoint = NWEndpoint.hostPort(
            host: NWEndpoint.Host("127.0.0.1"),
            port: Self.endpointPort
        )

        let newListener: NWListener
        do {
            newListener = try NWListener(using: params, on: Self.endpointPort)
        } catch {
            // Port busy, sandbox deny, etc. Record so AppState/UI can surface it.
            self.lastStartError = "Port \(Self.port) unavailable: \(error.localizedDescription)"
            return
        }

        self.listener = newListener

        newListener.stateUpdateHandler = { [weak self] state in
            if case .failed(let error) = state {
                self?.lastStartError = "Listener failed: \(error.localizedDescription)"
                self?.listener?.cancel()
                self?.listener = nil
            }
        }

        newListener.newConnectionHandler = { [weak self] connection in
            connection.start(queue: .global(qos: .utility))
            self?.receive(on: connection)
        }
        newListener.start(queue: .global(qos: .utility))
    }

    func stop() {
        listener?.cancel()
        listener = nil
    }

    // MARK: — Request handling

    private func receive(on connection: NWConnection, accumulated: Data = Data()) {
        // Guard against unbounded buffering from a slowloris-style client.
        if accumulated.count > Self.maxRequestBytes {
            respondPlain(statusCode: 431, statusMessage: "Request Header Fields Too Large", on: connection)
            return
        }

        connection.receive(minimumIncompleteLength: 1, maximumLength: 4096) {
            [weak self] data, _, isComplete, error in
            guard let self else { connection.cancel(); return }
            if error != nil { connection.cancel(); return }

            var buffer = accumulated
            if let data { buffer.append(data) }

            // Parse once we have a complete header block.
            if let _ = buffer.range(of: Data("\r\n\r\n".utf8)) {
                guard let request = String(data: buffer, encoding: .utf8) else {
                    connection.cancel(); return
                }
                let (method, path) = Self.parseMethodAndPath(from: request)
                let origin = Self.parseHeader("Origin", from: request)
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    if method == "OPTIONS" {
                        self.respondCORSPreflight(origin: origin, on: connection)
                        return
                    }
                    guard method == "GET" else {
                        self.respond(body: APIHandlers.methodNotAllowed(), on: connection,
                                     statusCode: 405, statusMessage: "Method Not Allowed",
                                     origin: origin)
                        return
                    }
                    let body = self.handle(path: path)
                    self.respond(body: body, on: connection, origin: origin)
                }
                return
            }

            if isComplete {
                connection.cancel()
                return
            }

            // Still waiting on rest of header — re-arm with accumulated buffer.
            self.receive(on: connection, accumulated: buffer)
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

        let model = appState.settings.selectedModel

        switch path {
        case "/health":
            return APIHandlers.health()
        case "/score":
            return APIHandlers.score(surface: surface, mode: mode, score: score)
        case "/recommendation":
            let cap = appState.capacity
                   ?? QueryCapacity(minQueries: 0, maxQueries: 0,
                                    minTokens: 0, maxTokens: 0,
                                    model: model, confidence: .low)
            return APIHandlers.recommendation(surface: surface, mode: mode,
                                              score: score, capacity: cap)
        case "/capacity":
            let cap = appState.capacity
                   ?? QueryCapacity(minQueries: 0, maxQueries: 0,
                                    minTokens: 0, maxTokens: 0,
                                    model: model, confidence: .low)
            return APIHandlers.capacity(cap)
        case "/best-window":
            return APIHandlers.bestWindow(appState.bestWindow)
        case "/explain":
            return APIHandlers.explain(score)
        default:
            return APIHandlers.notFound()
        }
    }

    private func respond(body: Data, on connection: NWConnection, statusCode: Int = 200, statusMessage: String = "OK", origin: String? = nil) {
        var header = "HTTP/1.1 \(statusCode) \(statusMessage)\r\nContent-Type: application/json\r\nContent-Length: \(body.count)\r\nConnection: close\r\n"
        if let allowed = Self.allowedOrigin(origin) {
            header += "Access-Control-Allow-Origin: \(allowed)\r\nVary: Origin\r\n"
        }
        header += "\r\n"
        var response = Data(header.utf8)
        response.append(body)
        connection.send(content: response, completion: .contentProcessed { _ in
            connection.cancel()
        })
    }

    private func respondCORSPreflight(origin: String?, on connection: NWConnection) {
        let allowed = Self.allowedOrigin(origin)
        var header = "HTTP/1.1 204 No Content\r\n"
        if let allowed {
            header += "Access-Control-Allow-Origin: \(allowed)\r\nAccess-Control-Allow-Methods: GET, OPTIONS\r\nAccess-Control-Allow-Headers: Content-Type\r\nVary: Origin\r\n"
        }
        header += "Connection: close\r\n\r\n"
        let response = Data(header.utf8)
        connection.send(content: response, completion: .contentProcessed { _ in
            connection.cancel()
        })
    }

    private func respondPlain(statusCode: Int, statusMessage: String, on connection: NWConnection) {
        let header = "HTTP/1.1 \(statusCode) \(statusMessage)\r\nContent-Length: 0\r\nConnection: close\r\n\r\n"
        connection.send(content: Data(header.utf8), completion: .contentProcessed { _ in
            connection.cancel()
        })
    }

    /// Allow-list: only loopback origins may read. Web pages served from
    /// http(s)://arbitrary-site.tld get no CORS headers, so the browser blocks
    /// the response. Matches the "local API, not public API" spirit of the toggle.
    private static func allowedOrigin(_ origin: String?) -> String? {
        guard let origin, let url = URL(string: origin),
              let host = url.host?.lowercased() else { return nil }
        if host == "localhost" || host == "127.0.0.1" || host == "[::1]" || host == "::1" {
            return origin
        }
        return nil
    }

    private static func parseMethodAndPath(from request: String) -> (method: String, path: String) {
        let lines = request.components(separatedBy: "\r\n")
        let parts = lines.first?.components(separatedBy: " ") ?? []
        guard parts.count >= 2 else { return ("GET", "/") }
        let method = parts[0]
        let path = parts[1].components(separatedBy: "?").first ?? "/"
        return (method, path)
    }

    private static func parseHeader(_ name: String, from request: String) -> String? {
        let needle = name.lowercased() + ":"
        for line in request.components(separatedBy: "\r\n").dropFirst() {
            if line.lowercased().hasPrefix(needle) {
                return String(line.dropFirst(needle.count)).trimmingCharacters(in: .whitespaces)
            }
        }
        return nil
    }
}
