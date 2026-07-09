import Foundation

// TimelineBuilder.swift — chronological evidence ordering (beats-Siri #3, M4).
// Invariant: constructs no network URLs; sorts in-memory Retrieved values only.

/// Reconstructs a chronological timeline from dated evidence (beats-Siri #3 —
/// temporal reasoning over your notes). Orders by the source's learned date,
/// falling back to the original order when dates are absent.
public enum TimelineBuilder {
    // A-090: lifecycle
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
    // A-150: grounding
    public static func citationIntegritySupported(_ s: String, evidence: [Retrieved]) -> Bool {
        GroundingCheck.citationIntegritySupported(s, evidence: evidence)
    }
    public static func unsupportedAnswerEvents() -> [QueryEvent] { GroundingCheck.unsupportedAnswerEvents() }

    // A-246: consolidation
    // MARK: - Dreaming safety (M8)
        /// Synthesis must cite constituents and not duplicate existing memories.
        public static func dreamingSafeSynthesis(_ candidate: String, existing: [MemoryEntry],
                                                  constituents: [String]) -> Bool {
            let live = existing.filter { $0.isLatest && !$0.isForgotten }.map(\.memory)
            guard !live.contains(candidate) else { return false }
            return constituents.allSatisfy { c in live.contains { $0.contains(c) || c.contains($0) } }
        }

    // A-350: latency
    // MARK: - Scheduling (M11)
        /// Interactive queries preempt utility background work at chunk boundaries.
        public static func schedulingYieldHint(priority: WorkPriority = .background) -> Bool {
            priority < .interactive
        }

    // A-298: intelligence
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


    public static func build(from evidence: [Retrieved]) -> [Retrieved] {
        let parser = ISO8601DateFormatter()
        func date(_ r: Retrieved) -> Date? { r.source.updatedAt.flatMap { parser.date(from: $0) } }
        // Stable sort: dated items ascending; undated keep relative position.
        return evidence.enumerated().sorted { a, b in
            switch (date(a.element), date(b.element)) {
            case let (.some(da), .some(db)): return da != db ? da < db : a.offset < b.offset
            case (.some, .none): return true
            case (.none, .some): return false
            default: return a.offset < b.offset
            }
        }.map(\.element)
    }
}
