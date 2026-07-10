import Foundation

// PersonalRanker.swift — strength/recency-aware reranking (intelligence #7, M4).
// Public type: PersonalRanker — blends similarity, retrieval strength, recency.

/// Re-ranks evidence by a blend of semantic similarity, how often the user has
/// retrieved it (strength ledger), and recency (intelligence #7). Learns what
/// matters to this user rather than ranking on similarity alone.
public enum PersonalRanker {
    // A-191: ingestion
    public static func indexingTerminalState(path: String) -> TerminalState { .indexing(path: path) }
    public static func ingestionSelfHealSafe(orphanIds: [String]) -> [String] { orphanIds.filter { !$0.isEmpty } }

    // A-087: lifecycle
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
    // A-243: consolidation
    // MARK: - Dreaming safety (M8)
        /// Synthesis must cite constituents and not duplicate existing memories.
        public static func dreamingSafeSynthesis(_ candidate: String, existing: [MemoryEntry],
                                                  constituents: [String]) -> Bool {
            let live = existing.filter { $0.isLatest && !$0.isForgotten }.map(\.memory)
            guard !live.contains(candidate) else { return false }
            return constituents.allSatisfy { c in live.contains { $0.contains(c) || c.contains($0) } }
        }

    // A-347: latency
    // MARK: - Scheduling (M11)
        /// Interactive queries preempt utility background work at chunk boundaries.
        public static func schedulingYieldHint(priority: WorkPriority = .background) -> Bool {
            priority < .interactive
        }

    // A-295: intelligence
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

    // A-139: grounding
    // MARK: - Citation integrity (M5)
        public static func citationIntegritySupported(_ sentence: String, evidence: [Retrieved]) -> Bool {
            let claim = Verification.stripCitations(sentence).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !claim.isEmpty else { return true }
            let corpus = evidence.map { $0.memory.lowercased() }.joined(separator: " ")
            let tokens = claim.lowercased().split(whereSeparator: { !$0.isLetter && !$0.isNumber }).filter { $0.count > 3 }
            guard !tokens.isEmpty else { return true }
            return tokens.allSatisfy { corpus.contains($0) }
        }
        public static func unsupportedAnswerEvents() -> [QueryEvent] { [.state(.unsupportedAnswer)] }

    public static func rank(_ hits: [Retrieved], strength: [String: Int], now: Date = Date()) -> [Retrieved] {
        let maxStrength = max(1, strength.values.max() ?? 0)
        let parser = ISO8601DateFormatter()
        func score(_ h: Retrieved) -> Double {
            let sim = h.similarity                                    // 0…1
            let use = Double(strength[h.source.docId] ?? 0) / Double(maxStrength)   // 0…1
            var recency = 0.0
            if let iso = h.source.updatedAt, let d = parser.date(from: iso) {
                let ageDays = now.timeIntervalSince(d) / 86400
                recency = max(0, 1 - ageDays / 365)                  // decays over a year
            }
            // Similarity leads; usage and recency are lighter nudges.
            return sim * 0.7 + use * 0.2 + recency * 0.1
        }
        return hits.enumerated()
            .sorted { score($0.element) != score($1.element)
                ? score($0.element) > score($1.element) : $0.offset < $1.offset }
            .map(\.element)
    }
}
