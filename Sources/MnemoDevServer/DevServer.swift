import Foundation
import Network
import MnemoCore

public enum DevServerError: Error { case badPort }

/// The loopback-only HTTP/SSE transport. Binds **127.0.0.1 exclusively** with
/// an explicit local endpoint plus a loopback-interface requirement, parses
/// each request, hands it to the pure `Router`, and for `/events` keeps the
/// socket open and streams the `DevTrace` feed. A single subscription to the
/// trace bus fans out to every connected browser tab.
public final class DevServer: @unchecked Sendable {
    public let token: String
    public let requestedPort: UInt16
    private let router: Router
    private let dataSource: DashboardDataSource
    private let queue = DispatchQueue(label: "ai.mnemo.devserver")
    private var listener: NWListener?
    private var sse: [ObjectIdentifier: NWConnection] = [:]   // touched only on `queue`
    private var broadcast: Task<Void, Never>?
    private var heartbeat: Task<Void, Never>?
    private var readyPort: UInt16?

    public init(port: UInt16, dataSource: DashboardDataSource, pageHTML: String,
                token: String = DevAuth.newToken()) {
        self.token = token
        self.requestedPort = port
        self.dataSource = dataSource
        let page = pageHTML.replacingOccurrences(of: "__MNEMO_TOKEN__", with: token)
        self.router = Router(token: token, dataSource: dataSource, page: page)
    }

    /// The port actually bound (useful when constructed with port 0 in tests).
    public func boundPort() -> UInt16? { queue.sync { readyPort } }

    public func start() throws {
        let params = NWParameters.tcp
        guard let nwPort = NWEndpoint.Port(rawValue: requestedPort) else { throw DevServerError.badPort }
        params.requiredInterfaceType = .loopback
        params.requiredLocalEndpoint = .hostPort(host: .ipv4(.loopback), port: nwPort)
        params.allowLocalEndpointReuse = true
        let listener = try NWListener(using: params)
        listener.stateUpdateHandler = { [weak self, weak listener] state in
            guard case .ready = state, let server = self else { return }
            let port = listener?.port?.rawValue
            server.queue.async { server.readyPort = port }
        }
        listener.newConnectionHandler = { [weak self] conn in self?.accept(conn) }
        listener.start(queue: queue)
        self.listener = listener
        startBroadcast()
        startHeartbeat()
    }

    public func stop() {
        broadcast?.cancel(); broadcast = nil
        heartbeat?.cancel(); heartbeat = nil
        queue.sync {
            for c in sse.values { c.cancel() }
            sse.removeAll()
        }
        listener?.cancel(); listener = nil
    }

    // MARK: - Live trace fan-out

    private func startBroadcast() {
        broadcast = Task { [weak self] in
            guard let self else { return }
            for await event in await self.dataSource.trace.subscribe() {
                if Task.isCancelled { break }
                guard let json = Self.encode(event) else { continue }
                let frame = SSE.frame(event: "trace", data: json, id: String(event.seq))
                self.queue.async { self.writeAllSSE(frame) }
            }
        }
    }

    private func startHeartbeat() {
        heartbeat = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(15))
                guard let server = self else { return }
                server.queue.async { server.writeAllSSE(SSE.comment("hb")) }
            }
        }
    }

    private func writeAllSSE(_ text: String) {
        let data = Data(text.utf8)
        for (id, conn) in sse {
            conn.send(content: data, completion: .contentProcessed { [weak self] error in
                guard error != nil, let server = self else { return }
                server.queue.async {
                    server.sse[id] = nil
                    conn.cancel()
                }
            })
        }
    }

    // MARK: - Connection lifecycle

    private func accept(_ conn: NWConnection) {
        conn.start(queue: queue)
        receive(conn, buffer: Data())
    }

    private func receive(_ conn: NWConnection, buffer: Data) {
        conn.receive(minimumIncompleteLength: 1, maximumLength: 65_536) { [weak self] data, _, isComplete, error in
            guard let self else { return }
            var buf = buffer
            if let data, !data.isEmpty { buf.append(data) }
            if let req = HTTPRequest.parse(buf), req.body.count >= req.contentLength {
                self.dispatch(req, on: conn)
            } else if isComplete || error != nil {
                conn.cancel()
            } else {
                self.receive(conn, buffer: buf)   // keep reading until the request is complete
            }
        }
    }

    private func dispatch(_ req: HTTPRequest, on conn: NWConnection) {
        Task { [weak self] in
            guard let self else { return }
            switch await self.router.handle(req) {
            case .unauthorized:
                self.send(.text("unauthorized", status: 401), on: conn)
            case .respond(let resp):
                self.send(resp, on: conn)
            case .sse:
                await self.beginSSE(on: conn)
            }
        }
    }

    private func send(_ resp: HTTPResponse, on conn: NWConnection) {
        conn.send(content: resp.serialize(), completion: .contentProcessed { _ in conn.cancel() })
    }

    private func beginSSE(on conn: NWConnection) async {
        // Snapshot + recent backlog first, so a tab that connects mid-query still
        // sees the in-flight stages; live events then arrive via the broadcast.
        let snap = await dataSource.snapshot()
        let backlog = await dataSource.trace.recentEvents()
        conn.stateUpdateHandler = { [weak self] state in
            switch state {
            case .cancelled, .failed:
                guard let server = self else { return }
                server.queue.async { server.sse[ObjectIdentifier(conn)] = nil }
            default: break
            }
        }
        queue.async { [weak self] in
            guard let self else { return }
            self.sse[ObjectIdentifier(conn)] = conn
            var initial = "HTTP/1.1 200 OK\r\nContent-Type: text/event-stream\r\n"
            initial += "Cache-Control: no-cache\r\nConnection: keep-alive\r\n\r\n"
            if let json = Self.encode(snap) { initial += SSE.frame(event: "snapshot", data: json) }
            for ev in backlog where Self.encode(ev) != nil {
                initial += SSE.frame(event: "trace", data: Self.encode(ev)!, id: String(ev.seq))
            }
            conn.send(content: Data(initial.utf8), completion: .contentProcessed { _ in })
        }
    }

    private static func encode<T: Encodable>(_ value: T) -> String? {
        guard let data = try? JSONEncoder().encode(value) else { return nil }
        return String(data: data, encoding: .utf8)
    }
}
