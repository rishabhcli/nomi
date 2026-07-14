import Foundation

/// A summary of one incremental sync pass by an `IngestSource`. (M13)
public struct IngestReport: Equatable, Sendable {
    public let kind: SourceKind
    public let container: String
    public let uploaded: Int
    public let unchanged: Int
    public let deferred: Int
    public let failures: Int
    public init(kind: SourceKind, container: String, uploaded: Int,
                unchanged: Int, deferred: Int, failures: Int) {
        self.kind = kind
        self.container = container
        self.uploaded = uploaded
        self.unchanged = unchanged
        self.deferred = deferred
        self.failures = failures
    }
}

/// A place Mnemo indexes from — a file tree, Messages, Mail, Calendar, Contacts,
/// Photos, browser history. Each source extracts ON DEVICE, ingests into its own
/// container (`kind.container`), stamps `mnemo_source_kind` provenance, and syncs
/// incrementally (via `SourceCheckpoint`) so re-runs are cheap. Nothing egresses:
/// every backend is the loopback engine. (M13)
public protocol IngestSource: Sendable {
    var kind: SourceKind { get }
    /// The Supermemory container this source writes to. Defaults to `kind.container`.
    var container: String { get }
    /// Run one incremental sync pass, ingesting at most `limit` new/changed items.
    @discardableResult
    func sync(limit: Int) async throws -> IngestReport
}

public extension IngestSource {
    var container: String { kind.container }
}
