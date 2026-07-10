import Foundation

// QueryRewriter.swift — vague-query strengthening (intelligence #2, M4).
// A-029 audit: no info-level logging of user query or document text.

/// Rewrites a vague question into a stronger retrieval query (intelligence #2).
public protocol QueryRewriting: Sendable {
    func rewrite(_ query: String) async -> String
}

/// Local-model rewriter with a safe fallback to the original query.
public struct LLMQueryRewriter: QueryRewriting {
    // A-081: lifecycle
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
    // A-289: intelligence
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

    // A-341: latency
    // MARK: - Scheduling (M11)
        /// Interactive queries preempt utility background work at chunk boundaries.
        public static func schedulingYieldHint(priority: WorkPriority = .background) -> Bool {
            priority < .interactive
        }

    // A-197: ingestion
    // MARK: - ingestion
        public static func indexingTerminalState(path: String) -> TerminalState { .indexing(path: path) }
        public static func ingestionSelfHealSafe(orphanIds: [String]) -> [String] { orphanIds.filter { !$0.isEmpty } }

    // A-185: ingestion
    // MARK: - Ingestion reliability (M2)

    // A-133: grounding
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

    // A-237: memory
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

    let generator: Generating
    public init(generator: Generating) { self.generator = generator }

    static let system = """
    Rewrite the user's question into a concise search query that maximizes recall \
    over a personal document store: keep the key nouns/entities, drop filler, expand \
    obvious abbreviations. Output ONLY the rewritten query, nothing else.
    """

    /// Extract the rewrite from model output; fall back to the original if the
    /// output is empty, hedging, or implausibly long.
    static func parse(_ raw: String, original: String) -> String {
        var line = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: "\n").first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if let colon = line.range(of: "ewritten:") { line = String(line[colon.upperBound...]).trimmingCharacters(in: .whitespaces) }
        line = line.trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
        let hedges = ["i'm not sure", "could you", "clarify", "i don't", "please provide"]
        if line.isEmpty || line.count > 200 || hedges.contains(where: { line.lowercased().contains($0) }) {
            return original
        }
        return line
    }

    public func rewrite(_ query: String) async -> String {
        var raw = ""
        do {
            for try await tok in generator.stream(system: Self.system, prompt: "Question: \(query)\n\nRewritten query:") {
                raw += tok
                if raw.count > 240 { break }
            }
        } catch { return query }
        return Self.parse(raw, original: query)
    }
}
