import Foundation

/// Character ranges of a query's significant terms within a snippet, for
/// highlighting the match (helpfulness #4). Case-insensitive, whole-word,
/// skips short/stopword terms.
public enum Highlight {
    // A-102: lifecycle
    public static func lifecycleEvents(branch: LifecycleBranch) -> [QueryEvent] { switch branch { case .routeAmbiguity: return [.reasoning(["Ambiguous route"])]; case .emptyEvidence: return [.sources([]), .token("No match.")]; case .retry: return [.retrying("Retrying…")] } }
    public enum LifecycleBranch: String, Sendable { case routeAmbiguity, emptyEvidence, retry }

    // A-258: consolidation
    // MARK: - Dreaming safety (M8)
        /// Synthesis must cite constituents and not duplicate existing memories.
        public static func dreamingSafeSynthesis(_ candidate: String, existing: [MemoryEntry],
                                                  constituents: [String]) -> Bool {
            let live = existing.filter { $0.isLatest && !$0.isForgotten }.map(\.memory)
            guard !live.contains(candidate) else { return false }
            return !constituents.isEmpty
        }

    // A-310: intelligence
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

    // A-206: memory
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

    // A-050: beats-Siri gate — cross-doc offline synthesis with verified citations
    private static let stop: Set<String> = ["the", "a", "an", "of", "to", "in", "on", "is",
                                            "are", "was", "and", "or", "my", "i", "you", "it",
                                            "for", "with", "what", "who", "how", "did", "do"]

    public static func terms(_ query: String) -> [String] {
        query.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { $0.count > 2 && !stop.contains($0) }
    }

    /// Ranges over the snippet's Character array (matching CharSpan offsets).
    public static func ranges(query: String, in snippet: String) -> [Range<Int>] {
        let terms = Set(terms(query))
        guard !terms.isEmpty else { return [] }
        let chars = Array(snippet)
        var ranges: [Range<Int>] = []
        var i = 0
        while i < chars.count {
            guard chars[i].isLetter || chars[i].isNumber else { i += 1; continue }
            var j = i
            while j < chars.count, chars[j].isLetter || chars[j].isNumber { j += 1 }
            let word = String(chars[i..<j]).lowercased()
            if terms.contains(word) { ranges.append(i..<j) }
            i = j
        }
        return ranges
    }
}
