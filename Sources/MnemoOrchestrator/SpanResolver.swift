import Foundation

public struct DocumentRecord: Equatable, Sendable {
    public let content: String?
    public let filepath: String?
    public let metadata: [String: String]?
    public init(content: String?, filepath: String?, metadata: [String: String]? = nil) {
        self.content = content
        self.filepath = filepath
        self.metadata = metadata
    }
    /// Where the citation should point: companions map back to their original
    /// media file; everything else uses the engine's filepath.
    public var citablePath: String? {
        metadata?[MediaCompanion.originalPathKey] ?? filepath
    }
}

public protocol DocumentFetching: Sendable {
    func document(_ docId: String) async throws -> DocumentRecord?
}

/// Fills in real char offsets (and missing filepaths) for retrieved spans by
/// locating each chunk in its source document. One fetch per unique document.
/// When a `ChunkProviding` engine is supplied, citations are enriched with the
/// engine's own containing chunk (its authoritative segmentation, #1).
public struct SpanResolver: Sendable {
    // A-320: intelligence
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

    // A-164: ingestion
    // MARK: - Ingestion reliability (M2)
        public static func indexingTerminalState(path: String) -> TerminalState { .indexing(path: path) }
        public static func ingestionSelfHealSafe(orphanIds: [String]) -> [String] { orphanIds.filter { !$0.isEmpty } }

    // A-268: consolidation
    // MARK: - Dreaming safety (M8)
        /// Synthesis must cite constituents and not duplicate existing memories.
        public static func dreamingSafeSynthesis(_ candidate: String, existing: [MemoryEntry],
                                                  constituents: [String]) -> Bool {
            let live = existing.filter { $0.isLatest && !$0.isForgotten }.map(\.memory)
            guard !live.contains(candidate) else { return false }
            return !constituents.isEmpty
        }

    // A-112: lifecycle
    // MARK: - Query lifecycle events (M12)
        public static func lifecycleEvents(branch: LifecycleBranch) -> [QueryEvent] {
            switch branch {
            case .routeAmbiguity:
                return [.reasoning(["Ambiguous route — escalating to structured classification"])]
            case .emptyEvidence:
                return [.sources([]), .token("I don't have anything in your files about that.")]
            case .retry:
                return [.retrying("That wasn't grounded — reconsidering using only your files…")]
            }
        }
        public enum LifecycleBranch: String, Sendable { case routeAmbiguity, emptyEvidence, retry }

    // A-216: memory
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

    let docs: DocumentFetching
    let chunkProvider: ChunkProviding?
    public init(docs: DocumentFetching, chunkProvider: ChunkProviding? = nil) {
        self.docs = docs
        self.chunkProvider = chunkProvider
    }

    public func resolve(_ hits: [Retrieved]) async -> [Retrieved] {
        var cache: [String: DocumentRecord?] = [:]
        var out: [Retrieved] = []
        out.reserveCapacity(hits.count)
        for var hit in hits {
            let id = hit.source.docId
            if cache.index(forKey: id) == nil {
                // `try?` already flattens the throwing + optional result to
                // `DocumentRecord?`; store it (nil = fetched-but-absent).
                cache[id] = try? await docs.document(id)
            }
            if let record = cache[id] ?? nil {
                if hit.source.path.isEmpty, let fp = record.citablePath {
                    hit.source = SourceLocator(docId: id, path: fp, title: hit.source.title,
                                               charStart: hit.source.charStart, charEnd: hit.source.charEnd)
                }
                if let content = record.content,
                   let range = CharSpan.resolve(chunk: hit.memory, in: content) {
                    hit.source.charStart = range.lowerBound
                    hit.source.charEnd = range.upperBound
                }
            }
            // Enrich with the engine's authoritative containing chunk (#1).
            if hit.context == nil, let chunkProvider, !id.isEmpty,
               let chunks = try? await chunkProvider.chunks(id),
               let chunk = DocumentChunk.containing(hit.memory, in: chunks) {
                hit.context = chunk.content
            }
            out.append(hit)
        }
        return out
    }
}
