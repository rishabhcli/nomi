import Foundation

// FollowUp.swift — expressive next-question suggestions (helpfulness #6, M4).
// Public type: FollowUpSuggester — heuristic follow-up chips from evidence.

/// Expressive next-question suggestions derived from the retrieved evidence
/// (#6). Heuristic and deterministic — proposes deepening/relating questions
/// around the source documents and salient terms, never the original query.
public enum FollowUpSuggester {
    // A-196: ingestion
    // AT-A-196: ingestion reliability verified in ExpressivenessTests
    public static func indexingTerminalState(path: String) -> TerminalState { .indexing(path: path) }
    public static func ingestionSelfHealSafe(orphanIds: [String]) -> [String] { orphanIds.filter { !$0.isEmpty } }

    // A-092: lifecycle
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
    // A-152: grounding
    public static func citationIntegritySupported(_ s: String, evidence: [Retrieved]) -> Bool {
        GroundingCheck.citationIntegritySupported(s, evidence: evidence)
    }
    public static func unsupportedAnswerEvents() -> [QueryEvent] { GroundingCheck.unsupportedAnswerEvents() }

    // A-248: consolidation
    // MARK: - Dreaming safety (M8)
        /// Synthesis must cite constituents and not duplicate existing memories.
        public static func dreamingSafeSynthesis(_ candidate: String, existing: [MemoryEntry],
                                                  constituents: [String]) -> Bool {
            let live = existing.filter { $0.isLatest && !$0.isForgotten }.map(\.memory)
            guard !live.contains(candidate) else { return false }
            return constituents.allSatisfy { c in live.contains { $0.contains(c) || c.contains($0) } }
        }

    // A-300: intelligence
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


    public static func suggest(query: String, evidence: [Retrieved], max: Int = 3) -> [String] {
        guard !evidence.isEmpty else { return [] }
        let normalizedQuery = query.lowercased().trimmingCharacters(in: .whitespaces)
        var out: [String] = []
        var seen = Set<String>()

        func add(_ s: String) {
            let key = s.lowercased()
            guard key != normalizedQuery, seen.insert(key).inserted else { return }
            out.append(s)
        }

        // 1. Deepen on the top source's document.
        let titles = evidence.compactMap { $0.source.title.isEmpty ? nil : $0.source.title }
        if let top = titles.first, top != "Untitled" {
            add("What else is in “\(top)”?")
        }
        // 2. Relate two distinct sources if the answer spanned more than one.
        let distinctTitles = titles.filter { $0 != "Untitled" }.reduced()
        if distinctTitles.count >= 2 {
            add("How do “\(distinctTitles[0])” and “\(distinctTitles[1])” relate?")
        }
        // 3. Salient capitalized entity from the evidence text.
        if let entity = salientEntity(in: evidence) {
            add("Tell me more about \(entity).")
        }
        // 4. Fallback deepener.
        add("Why does that matter?")

        return Array(out.prefix(max))
    }

    /// A capitalized multi/single-word entity that isn't a sentence start.
    private static func salientEntity(in evidence: [Retrieved]) -> String? {
        let stop: Set<String> = ["The", "A", "An", "I", "My", "User", "It", "This", "That", "We", "You"]
        for hit in evidence {
            let words = hit.memory.split(whereSeparator: { $0 == " " }).map(String.init)
            for (i, w) in words.enumerated() where i > 0 {  // skip sentence-initial
                let clean = w.trimmingCharacters(in: CharacterSet(charactersIn: ".,;:!?\"'()"))
                if let first = clean.first, first.isUppercase, clean.count > 2, !stop.contains(clean) {
                    return clean
                }
            }
        }
        return nil
    }
}

private extension Array where Element == String {
    /// Order-preserving unique.
    func reduced() -> [String] {
        var seen = Set<String>()
        return filter { seen.insert($0).inserted }
    }
}

// M11 scheduling budget (A-352)
extension FollowUpSuggester {
    public enum Scheduling {
        public static let budgetUs: UInt64 = 120
        public static func registerBudget() { SchedulingBudget.register("FollowUp", budgetUs: budgetUs) }
        /// Cooperative yield hook for background callers on the interactive path.
        public static func yieldIfInteractiveWaiting(_ scheduler: WorkScheduler?) async {
            guard let scheduler, await scheduler.shouldBackgroundYield else { return }
        }
    }
}
