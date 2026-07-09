import Foundation

/// Locates the cited span inside a source document. Char offsets are resolved
/// against the document's extracted text (see `CharSpan`); they are real,
/// checkable positions — never fabricated. `nil` means "not yet resolved".
public struct SourceLocator: Equatable, Sendable {
    public let docId: String
    public let path: String       // engine-relative filepath ("/notes/x.md"), "" if unknown
    public let title: String
    public var charStart: Int?
    public var charEnd: Int?
    public var updatedAt: String? // ISO8601 of when this fact was last learned
    public init(docId: String, path: String, title: String,
                charStart: Int? = nil, charEnd: Int? = nil, updatedAt: String? = nil) {
        self.docId = docId
        self.path = path
        self.title = title
        self.charStart = charStart
        self.charEnd = charEnd
        self.updatedAt = updatedAt
    }
}

public struct Retrieved: Equatable, Sendable {
    public let memory: String     // memory text (memories mode) or chunk text (documents/hybrid)
    public let similarity: Double
    public var source: SourceLocator
    public var context: String?   // fuller containing chunk (engine's native chunk, #1)
    public init(memory: String, similarity: Double, source: SourceLocator, context: String? = nil) {
        self.memory = memory
        self.similarity = similarity
        self.source = source
        self.context = context
    }
}

public struct SearchRequest: Sendable {
    public var q: String
    public var searchMode: String     // "memories" | "hybrid" | "documents"
    public var rerank: Bool
    public var threshold: Double
    public var limit: Int
    public var container: String?
    public init(q: String,
                searchMode: String = "memories",
                rerank: Bool = true,
                threshold: Double = 0.35,
                limit: Int = 12,
                container: String? = nil) {
        self.q = q
        self.searchMode = searchMode
        self.rerank = rerank
        self.threshold = threshold
        self.limit = limit
        self.container = container
    }
}

public protocol Retrieving: Sendable {
    func search(_ req: SearchRequest) async throws -> [Retrieved]
}
