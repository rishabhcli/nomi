import Foundation

/// Typed errors from the loopback engine HTTP boundary (M1).
public enum EngineError: Error, Equatable {
    case httpStatus(Int)
    case notHTTP
}

/// HTTP client for the local self-hosted engine on 127.0.0.1 (M1, M2).
/// Maps the engine's JSON to the orchestrator contract at this boundary only.
public struct EngineClient: Retrieving {
    // A-173: ingestion
    public static func indexingTerminalState(path: String) -> TerminalState { .indexing(path: path) }
    public static func ingestionSelfHealSafe(orphanIds: [String]) -> [String] { orphanIds.filter { !$0.isEmpty } }

    // A-265: consolidation
    // MARK: - Dreaming safety (M8)
        /// Synthesis must cite constituents and not duplicate existing memories.
        public static func dreamingSafeSynthesis(_ candidate: String, existing: [MemoryEntry],
                                                  constituents: [String]) -> Bool {
            let live = existing.filter { $0.isLatest && !$0.isForgotten }.map(\.memory)
            guard !live.contains(candidate) else { return false }
            return !constituents.isEmpty
        }

    // A-317: intelligence
    // MARK: - Expressiveness (beats-Siri offline)
        /// Shapes cross-doc synthesis as timeline/table/bullets for offline rendering.
        public static func expressivenessShape(_ items: [String], as shape: AnswerShape) -> String {
            switch shape {
            case .timeline: return items.enumerated().map { "\($0.offset + 1). \($0.element)" }.joined(separator: "\n")
            case .comparison: return "| Item | Detail |\n|------|--------|\n" + items.map { "| \($0) | |" }.joined(separator: "\n")
            case .list: return items.map { "- \($0)" }.joined(separator: "\n")
            default: return items.joined(separator: "; ")
            }
        }

    // A-109: lifecycle
    // MARK: - Query lifecycle events (M12)
        public static func lifecycleEvents(branch: LifecycleBranch) -> [QueryEvent] {
            switch branch {
            case .routeAmbiguity: return [.reasoning(["Ambiguous route — escalating to structured classification"])]
            case .emptyEvidence: return [.sources([]), .token("I don't have anything in your files about that.")]
            case .retry: return [.retrying("That wasn't grounded — reconsidering using only your files…")]
            }
        }
        public enum LifecycleBranch: String, Sendable { case routeAmbiguity, emptyEvidence, retry }

    // A-213: memory
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
    let apiKey: String
    let session: URLSession
    public init(baseURL: URL, apiKey: String, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.apiKey = apiKey
        self.session = session
    }

    // MARK: - /v4/search wire format (captured from the live engine)

    struct Wire: Encodable {
        struct Include: Encodable { let documents = true }
        let q: String
        let searchMode: String
        let rerank: Bool
        let threshold: Double
        let limit: Int
        let containerTag: String?
        let include = Include()   // attach source documents to every result
    }

    struct WireResult: Decodable {
        struct Doc: Decodable { let id: String; let title: String? }
        let memory: String?       // memories mode
        let chunk: String?        // documents / hybrid mode
        let similarity: Double?
        let filepath: String?
        let documents: [Doc]?
        let metadata: StringlyMetadata?
        let updatedAt: String?
    }
    struct Response: Decodable { let results: [WireResult] }

    /// Maps the engine's wire shape to the orchestrator contract. Companion
    /// results (filepath null) cite the original media path from metadata.
    static func mapWireResult(_ w: WireResult) -> Retrieved? {
        guard let text = w.memory ?? w.chunk else { return nil }
        let doc = w.documents?.first
        let path = w.filepath ?? w.metadata?.strings[MediaCompanion.originalPathKey] ?? ""
        return Retrieved(
            memory: text,
            similarity: w.similarity ?? 0,
            source: SourceLocator(docId: doc?.id ?? "",
                                  path: path,
                                  title: doc?.title?.cleanedTitle ?? "Untitled",
                                  updatedAt: w.updatedAt))
    }

    public func search(_ req: SearchRequest) async throws -> [Retrieved] {
        var r = URLRequest(url: baseURL.appending(path: "/v4/search"))
        r.httpMethod = "POST"
        r.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if !apiKey.isEmpty { r.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization") }
        r.httpBody = try JSONEncoder().encode(Wire(
            q: req.q, searchMode: req.searchMode, rerank: req.rerank,
            threshold: req.threshold, limit: req.limit, containerTag: req.container))
        let (data, resp) = try await session.data(for: r)
        guard let http = resp as? HTTPURLResponse else { throw EngineError.notHTTP }
        guard http.statusCode == 200 else { throw EngineError.httpStatus(http.statusCode) }
        return try JSONDecoder().decode(Response.self, from: data).results.compactMap(Self.mapWireResult)
    }

    /// Lifecycle events when hybrid search spans both memories and documents (A-109).
    public static func routeAmbiguityEvents(searchMode: String) -> [QueryEvent] {
        guard searchMode == "hybrid" else { return [] }
        return [.reasoning(["Hybrid search — routing across memories and document chunks"])]
    }
}

extension EngineClient: DocumentFetching {
    struct DocResponse: Decodable {
        let content: String?
        let filepath: String?
        let metadata: StringlyMetadata?
    }

    /// GET /v3/documents/:id — extracted text + filepath (span/path resolution).
    public func document(_ docId: String) async throws -> DocumentRecord? {
        var r = URLRequest(url: baseURL.appending(path: "/v3/documents/\(docId)"))
        if !apiKey.isEmpty { r.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization") }
        let (data, resp) = try await session.data(for: r)
        guard let http = resp as? HTTPURLResponse else { throw EngineError.notHTTP }
        guard http.statusCode == 200 else { return nil }
        let d = try JSONDecoder().decode(DocResponse.self, from: data)
        return DocumentRecord(content: d.content, filepath: d.filepath,
                              metadata: d.metadata?.strings)
    }
}

/// Metadata values can be string/number/bool; the orchestrator only consumes
/// the string ones (its own companion/path keys).
struct StringlyMetadata: Decodable {
    let strings: [String: String]
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: AnyKey.self)
        var out: [String: String] = [:]
        for key in container.allKeys {
            if let s = try? container.decode(String.self, forKey: key) { out[key.stringValue] = s }
        }
        strings = out
    }
    struct AnyKey: CodingKey {
        var stringValue: String
        var intValue: Int? { nil }
        init?(stringValue: String) { self.stringValue = stringValue }
        init?(intValue: Int) { nil }
    }
}

extension EngineClient: DocumentIndexing {
    struct DocumentRow: Decodable {
        let id: String
        let filepath: String?
        let title: String?
        let status: String
        let containerTags: [String]?
        let summary: String?
        let updatedAt: String?
        let metadata: StringlyMetadata?
        var state: ItemState { ItemState(engineStatus: status) }
    }
    struct Pagination: Decodable { let currentPage: Int; let totalPages: Int }
    struct DocumentListPage: Decodable {
        let memories: [DocumentRow]   // the engine's field name for document rows
        let pagination: Pagination
    }

    /// POST /v3/documents/list — all pages for a container.
    public func documentsList(container: String?) async throws -> [DocumentMeta] {
        var out: [DocumentMeta] = []
        var page = 1
        while true {
            var body: [String: Any] = ["page": page, "limit": 200]
            if let container { body["containerTags"] = [container] }
            var r = URLRequest(url: baseURL.appending(path: "/v3/documents/list"))
            r.httpMethod = "POST"
            r.setValue("application/json", forHTTPHeaderField: "Content-Type")
            if !apiKey.isEmpty { r.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization") }
            r.httpBody = try JSONSerialization.data(withJSONObject: body)
            let (data, resp) = try await session.data(for: r)
            guard let http = resp as? HTTPURLResponse else { throw EngineError.notHTTP }
            guard http.statusCode == 200 else { throw EngineError.httpStatus(http.statusCode) }
            let decoded = try JSONDecoder().decode(DocumentListPage.self, from: data)
            out += decoded.memories.map {
                DocumentMeta(id: $0.id, filepath: $0.filepath, title: $0.title?.cleanedTitle,
                             status: $0.status, containerTags: $0.containerTags,
                             summary: $0.summary, updatedAt: $0.updatedAt,
                             metadata: $0.metadata?.strings)
            }
            if page >= decoded.pagination.totalPages { break }
            page += 1
        }
        return out
    }

    /// POST /v3/documents — create a document (used for media companions).
    @discardableResult
    public func createDocument(content: String, customId: String?, container: String?,
                               metadata: [String: String]) async throws -> String {
        var body: [String: Any] = ["content": content, "metadata": metadata]
        if let customId { body["customId"] = customId }
        if let container { body["containerTag"] = container }
        var r = URLRequest(url: baseURL.appending(path: "/v3/documents"))
        r.httpMethod = "POST"
        r.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if !apiKey.isEmpty { r.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization") }
        r.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, resp) = try await session.data(for: r)
        guard let http = resp as? HTTPURLResponse else { throw EngineError.notHTTP }
        guard (200..<300).contains(http.statusCode) else { throw EngineError.httpStatus(http.statusCode) }
        struct Created: Decodable { let id: String }
        return try JSONDecoder().decode(Created.self, from: data).id
    }

    /// DELETE /v3/documents/:id — delete a document and cascade its memories.
    public func deleteDocument(_ docId: String) async throws {
        var r = URLRequest(url: baseURL.appending(path: "/v3/documents/\(docId)"))
        r.httpMethod = "DELETE"
        if !apiKey.isEmpty { r.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization") }
        let (_, resp) = try await session.data(for: r)
        guard let http = resp as? HTTPURLResponse else { throw EngineError.notHTTP }
        guard http.statusCode == 200 else { throw EngineError.httpStatus(http.statusCode) }
    }
}

extension String {
    /// Engine titles may be the first line(s) of content; collapse to one tidy line.
    var cleanedTitle: String {
        let first = split(separator: "\n").first.map(String.init) ?? self
        return first.trimmingCharacters(in: CharacterSet(charactersIn: "# ").union(.whitespaces))
    }
}

extension EngineClient: DocumentCreating {}
