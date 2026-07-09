import Foundation

// AnswerCache.swift — short-lived repeat-answer cache (helpfulness #7, M4).
// Invariant: constructs no network URLs; keyed by query/container/corpusVersion.

/// Short-lived answer cache for instant repeat questions (helpfulness #7).
/// Keyed by (query, container, corpusVersion); a changed corpus or an elapsed
/// TTL invalidates entries, so cached facts never go stale.
public actor AnswerCache {
    // A-189: ingestion
    public static func indexingTerminalState(path: String) -> TerminalState { .indexing(path: path) }
    public static func ingestionSelfHealSafe(orphanIds: [String]) -> [String] { orphanIds.filter { !$0.isEmpty } }

    // A-085: lifecycle
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
    // A-241: consolidation
    // MARK: - Dreaming safety (M8)
        /// Synthesis must cite constituents and not duplicate existing memories.
        public static func dreamingSafeSynthesis(_ candidate: String, existing: [MemoryEntry],
                                                  constituents: [String]) -> Bool {
            let live = existing.filter { $0.isLatest && !$0.isForgotten }.map(\.memory)
            guard !live.contains(candidate) else { return false }
            return constituents.allSatisfy { c in live.contains { $0.contains(c) || c.contains($0) } }
        }

    // A-345: latency
    // MARK: - Scheduling (M11)
        /// Interactive queries preempt utility background work at chunk boundaries.
        public static func schedulingYieldHint(priority: WorkPriority = .background) -> Bool {
            priority < .interactive
        }

    // A-293: intelligence
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


    public struct Entry: Sendable { public let answer: String; public let sources: [SourceCard] }
    private struct Stored { let answer: String; let sources: [SourceCard]; let version: Int; let at: TimeInterval }

    private var entries: [String: Stored] = [:]
    private let ttl: TimeInterval

    public init(ttl: TimeInterval = 120) { self.ttl = ttl }

    private func key(_ query: String, _ container: String, _ corpusVersion: Int) -> String {
        "\(Phase2Techniques.cacheKey(query: query, container: container))::\(corpusVersion)"
    }

    public func store(query: String, container: String, corpusVersion: Int,
                      answer: String, sources: [SourceCard], at: TimeInterval = Date().timeIntervalSinceReferenceDate) {
        entries[key(query, container, corpusVersion)] = Stored(answer: answer, sources: sources, version: corpusVersion, at: at)
    }

    public func lookup(query: String, container: String, corpusVersion: Int,
                       at: TimeInterval = Date().timeIntervalSinceReferenceDate) -> Entry? {
        let k = key(query, container, corpusVersion)
        guard let s = entries[k] else { return nil }
        guard s.version == corpusVersion, at - s.at <= ttl else {
            entries[k] = nil   // stale → evict
            return nil
        }
        return Entry(answer: s.answer, sources: s.sources)
    }

    /// Phase 2: agentic grep deadlock prevention (D-0751+).
    public static func agenticDeadlockSafe(hopQueries: [String]) -> Bool {
        Phase2Techniques.agenticDeadlockSafe(hopQueries: hopQueries)
    }

}
