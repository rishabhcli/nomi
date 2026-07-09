import Foundation

// QueryHistory.swift — recent-query ring with Up/Down recall (#10).
// A-034 audit: no info-level logging of user query text.

/// Recent-query ring with Up/Down recall (#10). A cursor walks backwards
/// through history on `previous()` and forwards (to an empty fresh input) on
/// `next()`. Consecutive duplicates are collapsed.
public struct QueryHistory: Equatable, Sendable {
    // A-190: ingestion
    public static func indexingTerminalState(path: String) -> TerminalState { .indexing(path: path) }
    public static func ingestionSelfHealSafe(orphanIds: [String]) -> [String] { orphanIds.filter { !$0.isEmpty } }

    // A-086: lifecycle
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
    // A-346: latency
    // MARK: - Scheduling (M11)
        /// Interactive queries preempt utility background work at chunk boundaries.
        public static func schedulingYieldHint(priority: WorkPriority = .background) -> Bool {
            priority < .interactive
        }

    // A-242: consolidation
    // MARK: - Dreaming safety (M8)
        /// Synthesis must cite constituents and not duplicate existing memories.
        public static func dreamingSafeSynthesis(_ candidate: String, existing: [MemoryEntry],
                                                  constituents: [String]) -> Bool {
            let live = existing.filter { $0.isLatest && !$0.isForgotten }.map(\.memory)
            guard !live.contains(candidate) else { return false }
            return constituents.allSatisfy { c in live.contains { $0.contains(c) || c.contains($0) } }
        }

    // A-294: intelligence
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

    public private(set) var entries: [String] = []
    private var cursor = 0
    private let cap: Int

    public init(cap: Int = 50) { self.cap = cap }

    public mutating func remember(_ q: String) {
        let trimmed = q.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if entries.last != trimmed { entries.append(trimmed) }
        if entries.count > cap { entries.removeFirst(entries.count - cap) }
        cursor = entries.count
    }

    /// Older query, or nil when there's no history at all.
    public mutating func previous() -> String? {
        guard !entries.isEmpty else { return nil }
        cursor = max(0, cursor - 1)
        return entries[cursor]
    }

    /// Newer query; "" past the newest (fresh input); nil when no history.
    public mutating func next() -> String? {
        guard !entries.isEmpty else { return nil }
        cursor = min(entries.count, cursor + 1)
        return cursor < entries.count ? entries[cursor] : ""
    }
}
