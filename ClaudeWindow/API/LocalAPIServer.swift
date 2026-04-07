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

        guard let listener = try? NWListener(
            using: params,
            on: NWEndpoint.Port(rawValue: Self.port)!
        ) else { return }

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
            let path = Self.parsePath(from: request)
            Task { @MainActor [weak self] in
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

    private func respond(body: Data, on connection: NWConnection) {
        let header = "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nContent-Length: \(body.count)\r\nAccess-Control-Allow-Origin: *\r\nConnection: close\r\n\r\n"
        var response = header.data(using: .utf8)!
        response.append(body)
        connection.send(content: response, completion: .contentProcessed { _ in
            connection.cancel()
        })
    }

    private static func parsePath(from request: String) -> String {
        let lines = request.components(separatedBy: "\r\n")
        let parts = lines.first?.components(separatedBy: " ") ?? []
        guard parts.count >= 2 else { return "/" }
        return parts[1].components(separatedBy: "?").first ?? "/"
    }
}
