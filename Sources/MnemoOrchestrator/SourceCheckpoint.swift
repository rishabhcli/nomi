import Foundation

/// A durable, per-source ingest checkpoint: maps a stable item key (a file path, a
/// Messages chat GUID, a Photos asset id, …) to the fingerprint last ingested and
/// the engine `documentId` it produced. Lets every `IngestSource` skip unchanged
/// items and resume after interruption. Generalized from the file-crawler's
/// original private checkpoint so all sources share one incremental model. (M13)
public actor SourceCheckpoint {
    public struct Entry: Codable, Equatable, Sendable {
        public let fingerprint: String
        public let documentId: String
        public init(fingerprint: String, documentId: String) {
            self.fingerprint = fingerprint
            self.documentId = documentId
        }
    }

    private let url: URL
    private var entries: [String: Entry]

    public init(url: URL) {
        self.url = url
        self.entries = Self.loadEntries(from: url)
    }

    /// True when `key` is already recorded with this exact `fingerprint` — i.e. the
    /// item is unchanged since it was last ingested and can be skipped.
    public func isUnchanged(key: String, fingerprint: String) -> Bool {
        entries[key]?.fingerprint == fingerprint
    }

    /// The engine document id previously produced for `key`, if any.
    public func documentId(for key: String) -> String? { entries[key]?.documentId }

    public var count: Int { entries.count }

    /// Record (or update) an item and persist the checkpoint atomically.
    public func record(key: String, fingerprint: String, documentId: String) throws {
        entries[key] = Entry(fingerprint: fingerprint, documentId: documentId)
        try persist()
    }

    /// Drop an item (e.g. its source file was deleted).
    public func forget(key: String) throws {
        guard entries.removeValue(forKey: key) != nil else { return }
        try persist()
    }

    private static func loadEntries(from url: URL) -> [String: Entry] {
        guard let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([String: Entry].self, from: data)
        else { return [:] }
        return decoded
    }

    private func persist() throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(entries).write(to: url, options: .atomic)
    }
}
