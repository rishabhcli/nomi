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
