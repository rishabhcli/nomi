import Foundation

/// Short-lived answer cache for instant repeat questions (helpfulness #7).
/// Keyed by (query, container, corpusVersion); a changed corpus or an elapsed
/// TTL invalidates entries, so cached facts never go stale.
public actor AnswerCache {
    public struct Entry: Sendable { public let answer: String; public let sources: [SourceCard] }
    private struct Stored { let answer: String; let sources: [SourceCard]; let version: Int; let at: TimeInterval }

    private var entries: [String: Stored] = [:]
    private let ttl: TimeInterval

    public init(ttl: TimeInterval = 120) { self.ttl = ttl }

    private func key(_ query: String, _ container: String) -> String {
        "\(container)::\(query.lowercased().trimmingCharacters(in: .whitespacesAndNewlines))"
    }

    public func store(query: String, container: String, corpusVersion: Int,
                      answer: String, sources: [SourceCard], at: TimeInterval = Date().timeIntervalSinceReferenceDate) {
        entries[key(query, container)] = Stored(answer: answer, sources: sources, version: corpusVersion, at: at)
    }

    public func lookup(query: String, container: String, corpusVersion: Int,
                       at: TimeInterval = Date().timeIntervalSinceReferenceDate) -> Entry? {
        guard let s = entries[key(query, container)] else { return nil }
        guard s.version == corpusVersion, at - s.at <= ttl else {
            entries[key(query, container)] = nil   // stale → evict
            return nil
        }
        return Entry(answer: s.answer, sources: s.sources)
    }
}
