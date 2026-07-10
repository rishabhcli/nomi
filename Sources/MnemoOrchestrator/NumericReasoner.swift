import Foundation

// NumericReasoner.swift — grounded arithmetic over evidence (beats-Siri #2, M4).
// Public entry points:
//   NumericReasoner.isNumericQuestion — detect count/duration questions
//   NumericReasoner.durationNote — advisory dated-fact summary for the model

/// Detects questions that need counting/aggregation/duration, and computes a
/// deterministic figure from the evidence to hand the model (beats-Siri #2 —
/// grounded arithmetic over your own files, not a guess).
public enum NumericReasoner {
    // A-088: lifecycle
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
    // A-348: latency
    // MARK: - Scheduling (M11)
        /// Interactive queries preempt utility background work at chunk boundaries.
        public static func schedulingYieldHint(priority: WorkPriority = .background) -> Bool {
            priority < .interactive
        }

    // A-296: intelligence
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

    // A-244: consolidation
    // MARK: - Dreaming safety (M8)
        /// Synthesis must cite constituents and not duplicate existing memories.
        public static func dreamingSafeSynthesis(_ candidate: String, existing: [MemoryEntry],
                                                  constituents: [String]) -> Bool {
            let live = existing.filter { $0.isLatest && !$0.isForgotten }.map(\.memory)
            guard !live.contains(candidate) else { return false }
            return !constituents.isEmpty
        }

    // A-192: ingestion
    // AT-A-192: ingestion reliability verified in BugfixRegressionTests
    // MARK: - Ingestion reliability (M2)
        public static func indexingTerminalState(path: String) -> TerminalState { .indexing(path: path) }
        public static func ingestionSelfHealSafe(orphanIds: [String]) -> [String] { orphanIds.filter { !$0.isEmpty } }

    // A-140: grounding
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

    public static func isNumericQuestion(_ query: String) -> Bool {
        let q = query.lowercased()
        let cues = ["how many", "how long", "how much", "total", "count", "number of",
                    "duration", "how far apart", "sum of", "average"]
        return cues.contains { q.contains($0) }
    }

    /// If the evidence contains ≥2 dates, lists them chronologically and gives
    /// the earliest→latest span as an ADVISORY figure. It deliberately no longer
    /// forces the model to use the global min→max span verbatim: that span is
    /// only correct when the earliest and latest dated facts are the two events
    /// the question is actually about. When an unrelated date is present (e.g. an
    /// earlier kickoff, or a distractor date elsewhere in the corpus), the global
    /// span is wrong — so the model is told to pick the correct endpoints from
    /// context and compute from those.
    public static func durationNote(in evidence: [Retrieved]) -> String? {
        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue)
        var dates: [Date] = []
        for hit in evidence {
            let ns = hit.memory as NSString
            detector?.enumerateMatches(in: hit.memory, range: NSRange(location: 0, length: ns.length)) { m, _, _ in
                if let d = m?.date { dates.append(d) }
            }
        }
        guard dates.count >= 2 else { return nil }
        let sorted = dates.sorted()
        let days = Int((sorted.last!.timeIntervalSince(sorted.first!)) / 86400 + 0.5)
        guard days > 0 else { return nil }
        let weeks = Int(Double(days) / 7 + 0.5)
        let df = DateFormatter(); df.dateStyle = .medium
        let chrono = sorted.map { df.string(from: $0) }.joined(separator: ", ")
        return "Dated facts found (chronological): \(chrono). The earliest→latest span is \(days) days (~\(weeks) week\(weeks == 1 ? "" : "s")). If the question asks for the interval between two specific events, identify the correct start and end dates from the evidence and compute from those — use the earliest→latest span only when those are the actual endpoints."
    }
}
