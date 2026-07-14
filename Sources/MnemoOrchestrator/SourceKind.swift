import Foundation

/// Which source a document (and the memories derived from it) was ingested from.
///
/// Every ingested document carries its `SourceKind` in metadata under
/// `SourceProvenance.sourceKindKey` (`mnemo_source_kind`), and each source maps to
/// its own Supermemory container (`space`) so it can be scoped in retrieval,
/// toggled on/off, and forgotten independently of the others. (M13)
public enum SourceKind: String, Codable, Sendable, CaseIterable {
    case file
    case messages
    case mail
    case calendar
    case contact
    case reminder
    case note
    case photo
    case browser

    /// The Supermemory container this source ingests into. Distinct per source so
    /// "forget my Messages" or "search only my files" is a container-scoped op.
    public var container: String {
        switch self {
        case .file: return "files"
        case .messages: return "messages"
        case .mail: return "mail"
        case .calendar: return "calendar"
        case .contact: return "contacts"
        case .reminder: return "reminders"
        case .note: return "notes"
        case .photo: return "photos"
        case .browser: return "browser"
        }
    }
}

/// Reads and writes the source-provenance metadata carried on every ingested
/// document. Kept as a tiny standalone surface so each ingestor depends only on
/// this, not on `SourceKind`'s container mapping. (M13)
public enum SourceProvenance {
    /// Metadata key under which the originating `SourceKind` is recorded.
    public static let sourceKindKey = "mnemo_source_kind"

    /// `metadata` with the source kind stamped in, preserving all existing keys
    /// (e.g. `mnemo_original_path`, `mnemo_file_fingerprint`).
    public static func stamp(_ kind: SourceKind, into metadata: [String: String] = [:]) -> [String: String] {
        var m = metadata
        m[sourceKindKey] = kind.rawValue
        return m
    }

    /// The source kind recorded in a metadata dictionary, or `nil` if absent or
    /// unrecognized.
    public static func kind(fromMetadata metadata: [String: String]?) -> SourceKind? {
        guard let raw = metadata?[sourceKindKey] else { return nil }
        return SourceKind(rawValue: raw)
    }

    /// The source kind recorded on a document, or `nil` if absent or unrecognized.
    public static func kind(of doc: DocumentMeta) -> SourceKind? {
        kind(fromMetadata: doc.metadata)
    }
}
