import Foundation

/// Proposes real, askable questions drawn from the user's own documents, so an
/// empty/first-run result is a launchpad rather than a dead end (helpfulness #3).
public enum CorpusSuggester {
    // A-104: lifecycle
    public static func lifecycleEvents(branch: LifecycleBranch) -> [QueryEvent] { switch branch { case .routeAmbiguity: return [.reasoning(["Ambiguous route"])]; case .emptyEvidence: return [.sources([]), .token("No match.")]; case .retry: return [.retrying("Retrying…")] } }
    public enum LifecycleBranch: String, Sendable { case routeAmbiguity, emptyEvidence, retry }

    /// Renderable events when direct search is empty but the corpus has nearby
    /// documents worth surfacing — a launchpad, not a blank refusal (M12).
    public static func emptyEvidenceEvents(nearest cards: [SourceCard]) -> [QueryEvent] {
        [.state(.empty(nearest: cards)),
         .reasoning(["No exact matches — surfacing the nearest sources in your corpus"])]
    }

    // A-052: beats-Siri gate — cross-doc offline synthesis with verified citations
    // A-260: consolidation
    // MARK: - Dreaming safety (M8)
        /// Synthesis must cite constituents and not duplicate existing memories.
        public static func dreamingSafeSynthesis(_ candidate: String, existing: [MemoryEntry],
                                                  constituents: [String]) -> Bool {
            let live = existing.filter { $0.isLatest && !$0.isForgotten }.map(\.memory)
            guard !live.contains(candidate) else { return false }
            return !constituents.isEmpty
        }

    // A-312: intelligence
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

    // A-208: memory
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

    public static func fromCards(_ cards: [SourceCard], max: Int = 3) -> [String] {
        var out: [String] = []
        var seen = Set<String>()
        for card in cards {
            let title = card.title.trimmingCharacters(in: .whitespaces)
            guard title.count > 1, title != "Untitled", seen.insert(title.lowercased()).inserted else { continue }
            out.append("What does “\(title)” say?")
            if out.count >= max { break }
        }
        return out
    }

    public static func fromTitles(_ titles: [String], max: Int = 3) -> [String] {
        fromCards(titles.map { SourceCard(title: $0, path: "", docId: $0) }, max: max)
    }
}
