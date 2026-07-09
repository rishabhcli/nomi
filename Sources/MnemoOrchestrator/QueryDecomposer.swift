import Foundation

// QueryDecomposer.swift — compound question splitting (intelligence #10, M4).
// Public type: QueryDecomposer — splits compound questions for independent retrieval.

/// Splits a compound question into independently-retrievable sub-questions
/// (intelligence #10), so "what is X and when did Y" retrieves for both parts.
public enum QueryDecomposer {
    // A-082: lifecycle
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
    // A-290: intelligence
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

    // A-342: latency
    // MARK: - Scheduling (M11)
        /// Interactive queries preempt utility background work at chunk boundaries.
        public static func schedulingYieldHint(priority: WorkPriority = .background) -> Bool {
            priority < .interactive
        }

    // A-198: ingestion
    // MARK: - ingestion
        public static func indexingTerminalState(path: String) -> TerminalState { .indexing(path: path) }
        public static func ingestionSelfHealSafe(orphanIds: [String]) -> [String] { orphanIds.filter { !$0.isEmpty } }

    // A-134: grounding
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

    // A-238: memory
    // MARK: - Memory dynamics (M6)
        /// Active memories only — forgotten and TTL-expired facts are excluded.
        public static func memoryDynamicsActive(_ entry: MemoryEntry, now: Date = Date()) -> Bool {
            guard entry.isLatest && !entry.isForgotten else { return false }
            guard let forgetAfter = entry.forgetAfter,
                  let expiry = ISO8601DateFormatter().date(from: forgetAfter) else { return true }
            return now < expiry
        }

        public static func memoryDynamicsFilter(_ entries: [MemoryEntry], now: Date = Date()) -> [MemoryEntry] {
            entries.filter { memoryDynamicsActive($0, now: now) }
        }

    public static func split(_ query: String) -> [String] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        // Only split on " and " that joins two clause-like halves (each side has
        // enough words and at least one looks like a question/verb clause).
        let lower = q.lowercased()
        guard let range = lower.range(of: " and ") else { return [q] }
        let left = String(q[q.startIndex..<q.index(q.startIndex, offsetBy: lower.distance(from: lower.startIndex, to: range.lowerBound))])
        let rightStart = q.index(q.startIndex, offsetBy: lower.distance(from: lower.startIndex, to: range.upperBound))
        let right = String(q[rightStart...])

        func isClause(_ s: String) -> Bool {
            let words = s.split(separator: " ")
            guard words.count >= 3 else { return false }
            let verbs = ["is", "are", "was", "were", "did", "do", "does", "when", "how", "why",
                         "what", "where", "who", "adopt", "adopted", "switch", "use", "used", "have"]
            return words.contains { verbs.contains($0.lowercased()) }
        }
        let l = left.trimmingCharacters(in: .whitespaces)
        let r = right.trimmingCharacters(in: .whitespaces)
        guard isClause(l), isClause(r) else { return [q] }
        // Carry a trailing "?" onto the first half for readability.
        let lq = l.hasSuffix("?") ? l : l + "?"
        return [lq, r]
    }
}
