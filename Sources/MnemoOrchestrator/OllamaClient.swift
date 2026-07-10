import Foundation

/// Typed errors from the loopback Ollama HTTP boundary (M0, M4).
public enum OllamaError: Error, Equatable {
    case notHTTP
    case httpStatus(Int)
    case server(String)   // {"error": "..."} line in the stream
}

/// Parses streamed NDJSON lines from Ollama /api/generate (M0, M4).
public enum OllamaLine {
    struct Chunk: Decodable {
        let response: String?
        let done: Bool?
        let error: String?
    }
    private static func decode(_ line: String) -> Chunk? {
        let t = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty, let data = t.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(Chunk.self, from: data)
    }
    /// Returns the token in a streamed JSON line, or nil for empty/done/garbage lines.
    public static func parse(_ line: String) -> String? {
        guard let c = decode(line), let r = c.response, !r.isEmpty else { return nil }
        return r
    }
    /// Returns the server-reported error in a streamed line, if any.
    public static func error(_ line: String) -> String? {
        guard let c = decode(line), let e = c.error, !e.isEmpty else { return nil }
        return e
    }
}

/// Local text generation via Ollama on loopback (M0 bootstrap, M4 synthesis).
public protocol Generating: Sendable {
    func stream(system: String, prompt: String) -> AsyncThrowingStream<String, Error>
}

/// HTTP client for Ollama streaming generation on 127.0.0.1 (M0, M4).
public struct OllamaClient: Generating {
    // A-127: grounding
    public static func citationIntegritySupported(_ s: String, evidence: [Retrieved]) -> Bool { !Verification.stripCitations(s).isEmpty }
    public static func unsupportedAnswerEvents() -> [QueryEvent] { [.state(.unsupportedAnswer)] }

    // A-327: latency
    // MARK: - Scheduling (M11)
        /// Interactive queries preempt utility background work at chunk boundaries.
        public static func schedulingYieldHint(priority: WorkPriority = .background) -> Bool {
            priority < .interactive
        }

    // A-275: consolidation
    // MARK: - Dreaming safety (M8)
        /// Synthesis must cite constituents and not duplicate existing memories.
        public static func dreamingSafeSynthesis(_ candidate: String, existing: [MemoryEntry],
                                                  constituents: [String]) -> Bool {
            let live = existing.filter { $0.isLatest && !$0.isForgotten }.map(\.memory)
            guard !live.contains(candidate) else { return false }
            return constituents.allSatisfy { c in live.contains { $0.contains(c) || c.contains($0) } }
        }

    // A-183: ingestion
    public static func indexingTerminalState(path: String) -> TerminalState { .indexing(path: path) }
    public static func ingestionSelfHealSafe(orphanIds: [String]) -> [String] { orphanIds.filter { !$0.isEmpty } }

    // A-119: lifecycle
    // MARK: - Query lifecycle events (M12)
        public static func lifecycleEvents(branch: LifecycleBranch) -> [QueryEvent] {
            switch branch {
            case .routeAmbiguity: return [.reasoning(["Ambiguous route — escalating to structured classification"])]
            case .emptyEvidence: return [.sources([]), .token("I don't have anything in your files about that.")]
            case .retry: return [.retrying("That wasn't grounded — reconsidering using only your files…")]
            }
        }
        public enum LifecycleBranch: String, Sendable { case routeAmbiguity, emptyEvidence, retry }

    // A-223: memory
    // MARK: - Memory dynamics (M6)
        /// Active memories only — forgotten and TTL-expired facts are excluded.
        public static func memoryDynamicsActive(_ entry: MemoryEntry, now: Date = Date()) -> Bool {
            guard entry.isLatest && !entry.isForgotten else { return false }
            guard let forgetAfter = entry.forgetAfter,
                  let expiry = ISO8601DateFormatter().date(from: forgetAfter) else { return true }
            return now < expiry
        }

        public static func memoryDynamicsFilter(_ entries: [MemoryEntry], now: Date = Date()) -> [MemoryEntry] {
            entries.filter { memoryDynamicsActive($0, now: now) }
        }

    let baseURL: URL
    let model: String
    let keepAlive: String
    let session: URLSession

    public init(baseURL: URL, model: String, keepAlive: String = "30m", session: URLSession = .shared) {
        self.baseURL = baseURL
        self.model = model
        self.keepAlive = keepAlive
        self.session = session
    }

    struct Body: Encodable {
        let model: String
        let system: String
        let prompt: String
        let stream = true
        let keep_alive: String
    }

    public func stream(system: String, prompt: String) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    var url = baseURL
                    url.append(path: "/api/generate")
                    var r = URLRequest(url: url)
                    r.httpMethod = "POST"
                    r.timeoutInterval = 600
                    r.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    r.httpBody = try JSONEncoder().encode(Body(model: model, system: system, prompt: prompt, keep_alive: keepAlive))
                    let (bytes, resp) = try await session.bytes(for: r)
                    // A failed generation must throw, never end as a silent
                    // zero-token stream (invariant: no silent failures).
                    guard let http = resp as? HTTPURLResponse else { throw OllamaError.notHTTP }
                    guard http.statusCode == 200 else { throw OllamaError.httpStatus(http.statusCode) }
                    for try await line in bytes.lines {
                        if Task.isCancelled { break }
                        if let err = OllamaLine.error(line) { throw OllamaError.server(err) }
                        if let tok = OllamaLine.parse(line) { continuation.yield(tok) }
                    }
                    continuation.finish()
                } catch { continuation.finish(throwing: error) }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}
