import Foundation

// ScopeClassifier.swift — corpus vs chit-chat gate (intelligence #9, M4).
// Public entry points:
//   ScopeClassifier.isCorpusQuestion — true when query needs retrieval
//   ScopeClassifier.reply — short-circuit reply for greetings/meta

/// Distinguishes real corpus questions from greetings / meta chit-chat, so the
/// assistant doesn't force a citation-hunting answer onto "hi" (intelligence #9).
public enum ScopeClassifier {
    // A-083: lifecycle
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
    // A-291: intelligence
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

    // A-239: memory
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

    // A-343: latency
    // MARK: - Scheduling (M11)
        /// Interactive queries preempt utility background work at chunk boundaries.
        public static func schedulingYieldHint(priority: WorkPriority = .background) -> Bool {
            priority < .interactive
        }

    // A-199: ingestion
    // MARK: - ingestion
        public static func indexingTerminalState(path: String) -> TerminalState { .indexing(path: path) }
        public static func ingestionSelfHealSafe(orphanIds: [String]) -> [String] { orphanIds.filter { !$0.isEmpty } }

    // A-135: grounding
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

    private static let chitChat: Set<String> = [
        "hi", "hey", "hello", "yo", "sup", "thanks", "thank you", "thx", "ok", "okay",
        "cool", "nice", "great", "bye", "goodbye", "good morning", "good night",
        "who are you", "what are you", "what can you do", "help me", "what is this",
    ]

    public static func isCorpusQuestion(_ query: String) -> Bool {
        let q = query.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: " ?!.,"))
        if q.isEmpty { return false }
        if chitChat.contains(q) { return false }
        // Very short non-question fragments that are pure greetings.
        if q.split(separator: " ").count <= 2 && chitChat.contains(where: { q.hasPrefix($0) }) { return false }
        return true
    }

    /// A friendly, honest reply for non-corpus input.
    public static func reply(for query: String) -> String {
        let q = query.lowercased()
        if q.contains("who are you") || q.contains("what are you") {
            return "I'm Mnemo — an on-device assistant that answers from your own files, fully offline."
        }
        if q.contains("what can you do") || q.contains("help") {
            return "Ask me anything about your files and I'll answer with citations. Type /help for commands."
        }
        if q.contains("thank") { return "Anytime." }
        return "Hi. Ask me something about your files and I'll dig in — or type /help."
    }
}
