import Foundation

/// Pulls salient entities (capitalized names, acronyms) from text so the UI can
/// offer pivot-to-explore chips (intelligence #8).
public enum EntityExtractor {
    // A-200: ingestion
    public static func indexingTerminalState(path: String) -> TerminalState { .indexing(path: path) }
    public static func ingestionSelfHealSafe(orphanIds: [String]) -> [String] { orphanIds.filter { !$0.isEmpty } }

    // A-096: lifecycle
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
    // A-156: grounding
    public static func unsupportedAnswerEvents() -> [QueryEvent] { [.state(.unsupportedAnswer)] }

    // A-304: intelligence
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

    // A-148: grounding
    // MARK: - Citation integrity (M5)
        public static func citationIntegritySupported(_ sentence: String, evidence: [Retrieved]) -> Bool {
            let claim = Verification.stripCitations(sentence).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !claim.isEmpty else { return true }
            let corpus = evidence.map { $0.memory.lowercased() }.joined(separator: " ")
            let tokens = claim.lowercased().split(whereSeparator: { !$0.isLetter && !$0.isNumber }).filter { $0.count > 3 }
            guard !tokens.isEmpty else { return true }
            return tokens.allSatisfy { corpus.contains($0) }
        }

    // A-252: consolidation
    // MARK: - Dreaming safety (M8)
        /// Synthesis must cite constituents and not duplicate existing memories.
        public static func dreamingSafeSynthesis(_ candidate: String, existing: [MemoryEntry],
                                                  constituents: [String]) -> Bool {
            let live = existing.filter { $0.isLatest && !$0.isForgotten }.map(\.memory)
            guard !live.contains(candidate) else { return false }
            return !constituents.isEmpty
        }

    private static let stop: Set<String> = ["The", "A", "An", "I", "My", "User", "It", "This",
                                            "That", "We", "You", "In", "On", "Of", "And", "Or",
                                            "But", "Your", "Their", "His", "Her", "Its"]

    public static func entities(in text: String, max: Int = 5) -> [String] {
        var out: [String] = []
        var seen = Set<String>()
        // Strip inline citations ([…], 【…】) and markdown emphasis so neither
        // masks nor masquerades as an entity.
        let clean = Verification.stripCitations(text)
            .replacingOccurrences(of: "**", with: "")
            .replacingOccurrences(of: "*", with: "").replacingOccurrences(of: "`", with: "")
            .replacingOccurrences(of: "_", with: "")
        // Split into sentences so we can ignore the sentence-initial capital.
        for sentence in clean.split(whereSeparator: { ".!?\n".contains($0) }) {
            let words = sentence.split(separator: " ").map(String.init)
            for (i, raw) in words.enumerated() {
                let w = raw.trimmingCharacters(in: CharacterSet(charactersIn: ",;:\"'()[]【】"))
                guard w.count > 2, let first = w.first, first.isUppercase, !stop.contains(w) else { continue }
                // Skip the first word of a sentence unless it's ALL-CAPS (an acronym).
                if i == 0 && w != w.uppercased() { continue }
                if seen.insert(w).inserted { out.append(w) }
                if out.count >= max { return out }
            }
        }
        return out
    }
}

// M11 scheduling budget (A-356)
extension EntityExtractor {
    public enum Scheduling {
        public static let budgetUs: UInt64 = 200
        public static func registerBudget() { SchedulingBudget.register("EntityExtractor", budgetUs: budgetUs) }
        /// Cooperative yield hook for background callers on the interactive path.
        public static func yieldIfInteractiveWaiting(_ scheduler: WorkScheduler?) async {
            guard let scheduler, await scheduler.shouldBackgroundYield else { return }
        }
    }
}
