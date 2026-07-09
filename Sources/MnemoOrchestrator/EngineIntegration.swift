import Foundation

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

/// Derives the set of containers (Supermemory spaces) from the document list —
/// the engine has no list-all endpoint, so we collect distinct tags (#4).
public enum ContainerCatalog {
    public static func distinct(_ docs: [DocumentMeta]) -> [String] {
        var seen = Set<String>()
        var out: [String] = []
        for d in docs { for t in d.containerTags ?? [] where seen.insert(t).inserted { out.append(t) } }
        return out.sorted()
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
