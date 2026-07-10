import Foundation

// EngineIntegration.swift — extended engine HTTP surface (M1–M3).
// Public entry points:
//   DocumentChunk / containing(_:in:) — engine chunk segmentation (#1)
//   ChunkProviding.chunks — fetch authoritative chunks per document
//   DocumentSearching.searchDocuments — chunk-level /v3/search
//   ConversationIngesting.ingestConversation — write exchanges to memory (#5)
//   ContainerCatalog.distinct — derive container tags from document list (#4)
//   EngineClient: chunks, searchDocuments, processing, ingestConversation,
//     bulkDelete, fileURL, containerContext, setContainerContext, uploadFile

// MARK: - Native chunks (#1)

/// A chunk as the engine itself segmented the document (`/v3/documents/:id/chunks`).
public struct DocumentChunk: Equatable, Sendable, Decodable {
    public let id: String
    public let position: Int
    public let content: String
    public init(id: String, position: Int, content: String) {
        self.id = id; self.position = position; self.content = content
    }
    /// The engine chunk that contains a retrieved snippet (word-overlap match).
    public static func containing(_ snippet: String, in chunks: [DocumentChunk]) -> DocumentChunk? {
        let needle = snippet.lowercased()
        return chunks.first { $0.content.lowercased().contains(needle) }
            ?? chunks.first { chunk in
                let words = snippet.lowercased().split(separator: " ").prefix(4)
                return !words.isEmpty && words.allSatisfy { chunk.content.lowercased().contains($0) }
            }
    }
}

/// Provides the engine's authoritative chunks for a document.
public protocol ChunkProviding: Sendable {
    func chunks(_ docId: String) async throws -> [DocumentChunk]
}

/// Searches documents at chunk granularity (`/v3/search`) — a distinct surface
/// from memory search, with per-chunk relevance scores.
public protocol DocumentSearching: Sendable {
    func searchDocuments(_ q: String, container: String?, limit: Int) async throws -> [Retrieved]
}

/// Writes a completed exchange back into the engine as a conversation (#5).
public protocol ConversationIngesting: Sendable {
    func ingestConversation(id: String, messages: [(role: String, content: String)], container: String?) async throws
}

/// Per-document extraction failure summary (A-048) — surfaces errors without blocking queries.
public struct ExtractionFailureReport: Equatable, Sendable {
    public let failed: [DocumentMeta]
    public let retryPolicy: String
    public static func build(from docs: [DocumentMeta]) -> ExtractionFailureReport {
        let failed = docs.filter { ItemState(engineStatus: $0.status) == .error }
        let policy = failed.isEmpty ? ""
            : "\(failed.count) document(s) failed extraction; chunk-level search still works. Retries on next sync."
        return ExtractionFailureReport(failed: failed, retryPolicy: policy)
    }
}

/// Derives the set of containers (Supermemory spaces) from the document list —
/// the engine has no list-all endpoint, so we collect distinct tags (#4).
public enum ContainerCatalog {
    // A-266: consolidation
    // MARK: - Dreaming safety (M8)
        /// Synthesis must cite constituents and not duplicate existing memories.
        public static func dreamingSafeSynthesis(_ candidate: String, existing: [MemoryEntry],
                                                  constituents: [String]) -> Bool {
            let live = existing.filter { $0.isLatest && !$0.isForgotten }.map(\.memory)
            guard !live.contains(candidate) else { return false }
            return constituents.allSatisfy { c in live.contains { $0.contains(c) || c.contains($0) } }
        }

    // A-318: intelligence
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

    // A-110: lifecycle
    // MARK: - Query lifecycle events (M12)
        public static func lifecycleEvents(branch: LifecycleBranch) -> [QueryEvent] {
            switch branch {
            case .routeAmbiguity: return [.reasoning(["Ambiguous route — escalating to structured classification"])]
            case .emptyEvidence: return [.sources([]), .token("I don't have anything in your files about that.")]
            case .retry: return [.retrying("That wasn't grounded — reconsidering using only your files…")]
            }
        }
        public enum LifecycleBranch: String, Sendable { case routeAmbiguity, emptyEvidence, retry }

    // A-162: ingestion
    // MARK: - Ingestion reliability (M2)
        public static func indexingTerminalState(path: String) -> TerminalState { .indexing(path: path) }
        public static func ingestionSelfHealSafe(orphanIds: [String]) -> [String] { orphanIds.filter { !$0.isEmpty } }

    // A-214: memory
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

    public static func distinct(_ docs: [DocumentMeta]) -> [String] {
        var seen = Set<String>()
        var out: [String] = []
        for d in docs { for t in d.containerTags ?? [] where seen.insert(t).inserted { out.append(t) } }
        return out.sorted()
    }

    /// Renderable events when chunk-level search returns nothing (A-110).
    public static func emptyEvidenceEvents(chunks: [DocumentChunk]) -> [QueryEvent] {
        guard chunks.isEmpty else { return [] }
        return [.state(.empty(nearest: [])), .reasoning(["No document chunks matched the query"])]
    }
}

extension EngineClient: ChunkProviding, DocumentSearching, ConversationIngesting {
    private func authorized(_ url: URL, method: String = "GET") -> URLRequest {
        var r = URLRequest(url: url)
        r.httpMethod = method
        if !apiKey.isEmpty { r.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization") }
        return r
    }
    private func jsonBody(_ url: URL, method: String, _ body: [String: Any]) throws -> URLRequest {
        var r = authorized(url, method: method)
        r.setValue("application/json", forHTTPHeaderField: "Content-Type")
        r.httpBody = try JSONSerialization.data(withJSONObject: body)
        return r
    }
    private func ok(_ resp: URLResponse) throws {
        guard let http = resp as? HTTPURLResponse else { throw EngineError.notHTTP }
        guard (200..<300).contains(http.statusCode) else { throw EngineError.httpStatus(http.statusCode) }
    }

    // #1 — chunks
    public func chunks(_ docId: String) async throws -> [DocumentChunk] {
        struct Wire: Decodable { let chunks: [DocumentChunk] }
        let (data, resp) = try await session.data(for: authorized(baseURL.appending(path: "/v3/documents/\(docId)/chunks")))
        try ok(resp)
        return try JSONDecoder().decode(Wire.self, from: data).chunks
    }

    // #9 — document (chunk-level) search
    public func searchDocuments(_ q: String, container: String?, limit: Int) async throws -> [Retrieved] {
        struct Chunk: Decodable { let content: String; let isRelevant: Bool?; let score: Double? }
        struct Result: Decodable {
            let documentId: String?; let title: String?; let score: Double?
            let updatedAt: String?; let chunks: [Chunk]?
        }
        struct Wire: Decodable { let results: [Result] }
        var body: [String: Any] = ["q": q, "limit": limit]
        if let container { body["containerTags"] = [container] }
        let (data, resp) = try await session.data(for: try jsonBody(baseURL.appending(path: "/v3/search"), method: "POST", body))
        try ok(resp)
        return try JSONDecoder().decode(Wire.self, from: data).results.compactMap { r in
            let chunk = r.chunks?.first { $0.isRelevant == true } ?? r.chunks?.first
            guard let text = chunk?.content else { return nil }
            return Retrieved(memory: text, similarity: chunk?.score ?? r.score ?? 0,
                             source: SourceLocator(docId: r.documentId ?? "", path: "",
                                                   title: r.title?.cleanedTitle ?? "Untitled",
                                                   updatedAt: r.updatedAt))
        }
    }

    // #3 — native processing status
    public func processing(container: String?) async throws -> [DocumentMeta] {
        struct Doc: Decodable { let id: String; let status: String; let filepath: String?; let title: String? }
        struct Wire: Decodable { let documents: [Doc] }
        var url = baseURL.appending(path: "/v3/documents/processing")
        if let container { url.append(queryItems: [URLQueryItem(name: "containerTag", value: container)]) }
        let (data, resp) = try await session.data(for: authorized(url))
        try ok(resp)
        return try JSONDecoder().decode(Wire.self, from: data).documents.map {
            DocumentMeta(id: $0.id, filepath: $0.filepath, title: $0.title, status: $0.status,
                         containerTags: container.map { [$0] }, summary: nil, updatedAt: nil)
        }
    }

    // #5 — write a conversation back into memory
    public func ingestConversation(id: String, messages: [(role: String, content: String)], container: String?) async throws {
        var body: [String: Any] = [
            "conversationId": id,
            "messages": messages.map { ["role": $0.role, "content": $0.content] },
        ]
        if let container { body["containerTags"] = [container] }
        let (_, resp) = try await session.data(for: try jsonBody(baseURL.appending(path: "/v4/conversations"), method: "POST", body))
        try ok(resp)
    }

    // #7 — bulk delete (by ids or whole container)
    @discardableResult
    public func bulkDelete(ids: [String]? = nil, container: String? = nil) async throws -> Int {
        struct Wire: Decodable { let deletedCount: Int? }
        var body: [String: Any] = [:]
        if let ids { body["ids"] = ids }
        if let container { body["containerTags"] = [container] }
        let (data, resp) = try await session.data(for: try jsonBody(baseURL.appending(path: "/v3/documents/bulk"), method: "DELETE", body))
        try ok(resp)
        return (try? JSONDecoder().decode(Wire.self, from: data).deletedCount ?? 0) ?? 0
    }

    // #8 — presigned URL of the engine's stored original file
    public func fileURL(_ docId: String) async throws -> String? {
        struct Wire: Decodable { let url: String? }
        let (data, resp) = try await session.data(for: authorized(baseURL.appending(path: "/v3/documents/\(docId)/file-url")))
        guard (resp as? HTTPURLResponse)?.statusCode == 200 else { return nil }
        return (try? JSONDecoder().decode(Wire.self, from: data))?.url
    }

    // #6 — per-container context prompt (shapes what becomes memory)
    public func containerContext(_ tag: String) async throws -> String? {
        struct Wire: Decodable { let entityContext: String? }
        let (data, resp) = try await session.data(for: authorized(baseURL.appending(path: "/v3/container-tags/\(tag)")))
        try ok(resp)
        return (try? JSONDecoder().decode(Wire.self, from: data))?.entityContext
    }
    public func setContainerContext(_ tag: String, context: String) async throws {
        let (_, resp) = try await session.data(for: try jsonBody(
            baseURL.appending(path: "/v3/container-tags/\(tag)"), method: "PATCH", ["entityContext": context]))
        try ok(resp)
    }

    // #2 — upload an arbitrary file through the engine (multipart)
    @discardableResult
    public func uploadFile(_ fileURL: URL, container: String?) async throws -> String {
        let boundary = "mnemo-\(UUID().uuidString)"
        var r = authorized(baseURL.appending(path: "/v3/documents/file"), method: "POST")
        r.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        var data = Data()
        func field(_ name: String, _ value: String) {
            data.append("--\(boundary)\r\nContent-Disposition: form-data; name=\"\(name)\"\r\n\r\n\(value)\r\n".data(using: .utf8)!)
        }
        let bytes = try Data(contentsOf: fileURL)
        data.append("--\(boundary)\r\nContent-Disposition: form-data; name=\"file\"; filename=\"\(fileURL.lastPathComponent)\"\r\nContent-Type: application/octet-stream\r\n\r\n".data(using: .utf8)!)
        data.append(bytes)
        data.append("\r\n".data(using: .utf8)!)
        if let container { field("containerTag", container) }
        data.append("--\(boundary)--\r\n".data(using: .utf8)!)
        r.httpBody = data
        let (respData, resp) = try await session.data(for: r)
        try ok(resp)
        struct Wire: Decodable { let id: String }
        return (try? JSONDecoder().decode(Wire.self, from: respData).id) ?? ""
    }
}
