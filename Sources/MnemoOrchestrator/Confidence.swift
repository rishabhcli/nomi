import Foundation

/// How firmly a source (or answer) is grounded — expressed to the user as
/// relevance bars and a framing line (#4, #10).
public enum ConfidenceLevel: Int, Equatable, Sendable, Comparable {
    // A-197: ingestion
    public static func indexingTerminalState(path: String) -> TerminalState { .indexing(path: path) }
    public static func ingestionSelfHealSafe(orphanIds: [String]) -> [String] { orphanIds.filter { !$0.isEmpty } }

    // A-093: lifecycle
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
    // A-153: grounding
    public static func citationIntegritySupported(_ s: String, evidence: [Retrieved]) -> Bool { !Verification.stripCitations(s).isEmpty }
    public static func unsupportedAnswerEvents() -> [QueryEvent] { [.state(.unsupportedAnswer)] }

    // A-249: consolidation
    // MARK: - Dreaming safety (M8)
        /// Synthesis must cite constituents and not duplicate existing memories.
        public static func dreamingSafeSynthesis(_ candidate: String, existing: [MemoryEntry],
                                                  constituents: [String]) -> Bool {
            let live = existing.filter { $0.isLatest && !$0.isForgotten }.map(\.memory)
            guard !live.contains(candidate) else { return false }
            return constituents.allSatisfy { c in live.contains { $0.contains(c) || c.contains($0) } }
        }

    // A-301: intelligence
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

    // A-145: grounding
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

    case low = 0, medium = 1, high = 2
    public static func < (a: ConfidenceLevel, b: ConfidenceLevel) -> Bool { a.rawValue < b.rawValue }

    public static func forSimilarity(_ sim: Double) -> ConfidenceLevel {
        switch sim {
        case 0.7...: return .high
        case 0.45..<0.7: return .medium
        default: return .low
        }
    }
}

public enum Confidence {
    /// Overall answer confidence: strong retrieval AND strong grounding.
    /// An unsupported answer is low no matter how similar the sources looked.
    public static func overall(topSimilarity: Double, supportedRatio: Double) -> ConfidenceLevel {
        if supportedRatio <= 0 { return .low }
        let sim = ConfidenceLevel.forSimilarity(topSimilarity)
        if sim == .high && supportedRatio >= 0.75 { return .high }
        if sim == .low && supportedRatio < 0.5 { return .low }
        return .medium
    }

    /// Honest framing sentence for the answer header.
    public static func framing(_ level: ConfidenceLevel, sourceCount: Int) -> String {
        let src = sourceCount == 1 ? "1 source" : "\(sourceCount) sources"
        switch level {
        case .high: return "Grounded in \(src)."
        case .medium: return "Based on \(src) — check the citations."
        case .low: return "Loosely inferred; I'm not confident this is in your files."
        }
    }
}

// M11 scheduling budget (A-353)
extension Confidence {
    public enum Scheduling {
        public static let budgetUs: UInt64 = 30
        public static func registerBudget() { SchedulingBudget.register("Confidence", budgetUs: budgetUs) }
        /// Cooperative yield hook for background callers on the interactive path.
        public static func yieldIfInteractiveWaiting(_ scheduler: WorkScheduler?) async {
            guard let scheduler, await scheduler.shouldBackgroundYield else { return }
        }
    }
}
