import Foundation

// Profile.swift — user identity preamble for generation (M3).
// Public types: Profile (M3), ProfileFetching (M3), ProfileDedupe (M3) — dedupe tiers.

/// What Mnemo already knows about you (PLAN.md M3): stable identity facts,
/// current-but-changeable facts, and query-relevant memories.
public struct Profile: Equatable, Sendable {
    // A-077: beats-Siri gate — cross-doc offline synthesis with verified citations
    public let statics: [String]
    public let dynamics: [String]
    public let memories: [Retrieved]
    public init(statics: [String], dynamics: [String], memories: [Retrieved]) {
        self.statics = statics
        self.dynamics = dynamics
        self.memories = memories
    }
}

public protocol ProfileFetching: Sendable {
    func profile(_ q: String, container: String?) async throws -> Profile
}

/// Client-side dedupe across tiers, priority static > dynamic > search
/// (PLAN.md global API contract).
public enum ProfileDedupe {
    // A-337: latency
    // MARK: - Scheduling (M11)
        /// Interactive queries preempt utility background work at chunk boundaries.
        public static func schedulingYieldHint(priority: WorkPriority = .background) -> Bool {
            priority < .interactive
        }

    // A-193: ingestion
    // MARK: - ingestion
        public static func indexingTerminalState(path: String) -> TerminalState { .indexing(path: path) }
        public static func ingestionSelfHealSafe(orphanIds: [String]) -> [String] { orphanIds.filter { !$0.isEmpty } }

    // A-285: intelligence
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


    // A-233: memory
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

    static func normalize(_ s: String) -> String {
        s.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    /// Exposed for preamble staleness checks (ContextAssembler).
    public static func normalizedFact(_ s: String) -> String { normalize(s) }

    public static func dedupe(_ p: Profile) -> Profile {
        var seen = Set<String>()
        let statics = p.statics.filter { seen.insert(normalize($0)).inserted }
        let dynamics = p.dynamics.filter { seen.insert(normalize($0)).inserted }
        let memories = p.memories.filter { seen.insert(normalize($0.memory)).inserted }
        return Profile(statics: statics, dynamics: dynamics, memories: memories)
    }
}

extension EngineClient: MemoryStoring {
    struct MemoryListPage: Decodable {
        let memoryEntries: [MemoryEntry]
        struct Pagination: Decodable { let currentPage: Int; let totalPages: Int }
        let pagination: Pagination
    }
    private struct CreatedMemory: Decodable {
        struct Item: Decodable { let id: String }
        let memories: [Item]
    }
    private struct SupersededMemory: Decodable { let id: String }

    private func memoryRequest(_ method: String, _ body: [String: Any]) throws -> URLRequest {
        var r = URLRequest(url: baseURL.appending(path: "/v4/memories"))
        r.httpMethod = method
        r.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if !apiKey.isEmpty { r.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization") }
        r.httpBody = try JSONSerialization.data(withJSONObject: body)
        return r
    }

    public func createMemory(content: String, isStatic: Bool, forgetAfter: String?, container: String?) async throws -> String {
        var mem: [String: Any] = ["content": content, "isStatic": isStatic]
        if let forgetAfter { mem["forgetAfter"] = forgetAfter }
        let body: [String: Any] = ["memories": [mem], "containerTag": container ?? "default"]
        let (data, resp) = try await session.data(for: try memoryRequest("POST", body))
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw EngineError.httpStatus((resp as? HTTPURLResponse)?.statusCode ?? -1)
        }
        return try JSONDecoder().decode(CreatedMemory.self, from: data).memories.first?.id ?? ""
    }

    public func supersedeMemory(id: String, newContent: String, container: String?) async throws -> String {
        let body: [String: Any] = ["id": id, "newContent": newContent, "containerTag": container ?? "default"]
        let (data, resp) = try await session.data(for: try memoryRequest("PATCH", body))
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw EngineError.httpStatus((resp as? HTTPURLResponse)?.statusCode ?? -1)
        }
        return try JSONDecoder().decode(SupersededMemory.self, from: data).id
    }

    public func forgetMemory(id: String, reason: String, container: String?) async throws {
        let body: [String: Any] = ["id": id, "reason": reason, "containerTag": container ?? "default"]
        let (_, resp) = try await session.data(for: try memoryRequest("DELETE", body))
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw EngineError.httpStatus((resp as? HTTPURLResponse)?.statusCode ?? -1)
        }
    }

    /// Forget by exact content match (used by `/forget <fact>`, when no id is
    /// known). The engine accepts `content` in place of `id`.
    public func forgetMemory(content: String, reason: String, container: String?) async throws {
        let body: [String: Any] = ["content": content, "reason": reason, "containerTag": container ?? "default"]
        let (_, resp) = try await session.data(for: try memoryRequest("DELETE", body))
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw EngineError.httpStatus((resp as? HTTPURLResponse)?.statusCode ?? -1)
        }
    }

    public func listMemories(container: String?) async throws -> [MemoryEntry] {
        var out: [MemoryEntry] = []
        var page = 1
        while true {
            let body: [String: Any] = ["containerTags": [container ?? "default"], "page": page, "limit": 200]
            var r = URLRequest(url: baseURL.appending(path: "/v4/memories/list"))
            r.httpMethod = "POST"
            r.setValue("application/json", forHTTPHeaderField: "Content-Type")
            if !apiKey.isEmpty { r.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization") }
            r.httpBody = try JSONSerialization.data(withJSONObject: body)
            let (data, resp) = try await session.data(for: r)
            guard let http = resp as? HTTPURLResponse, http.statusCode == 200 else {
                throw EngineError.httpStatus((resp as? HTTPURLResponse)?.statusCode ?? -1)
            }
            let decoded = try JSONDecoder().decode(MemoryListPage.self, from: data)
            out += decoded.memoryEntries
            if page >= decoded.pagination.totalPages { break }
            page += 1
        }
        return out
    }
}

extension EngineClient: ProfileFetching {
    struct ProfileTiers: Decodable {
        let `static`: [String]
        let dynamic: [String]
    }
    struct ProfileEnvelope: Decodable {
        let profile: ProfileTiers
        let searchResults: Response
    }

    /// POST /v4/profile — static + dynamic facts + query-relevant memories,
    /// deduped client-side (static wins ties).
    public func profile(_ q: String, container: String?) async throws -> Profile {
        var body: [String: Any] = ["q": q]
        body["containerTag"] = container ?? "default"
        var r = URLRequest(url: baseURL.appending(path: "/v4/profile"))
        r.httpMethod = "POST"
        r.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if !apiKey.isEmpty { r.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization") }
        r.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, resp) = try await session.data(for: r)
        guard let http = resp as? HTTPURLResponse else { throw EngineError.notHTTP }
        guard http.statusCode == 200 else { throw EngineError.httpStatus(http.statusCode) }
        let envelope = try JSONDecoder().decode(ProfileEnvelope.self, from: data)
        return ProfileDedupe.dedupe(Profile(
            statics: envelope.profile.static,
            dynamics: envelope.profile.dynamic,
            memories: envelope.searchResults.results.compactMap(Self.mapWireResult)))
    }
}
