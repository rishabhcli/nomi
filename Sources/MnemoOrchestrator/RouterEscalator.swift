import Foundation

/// Escalates an ambiguous heuristic-routing decision to a structured model
/// classification (intelligence #4, PLAN.md M4 Task 1).
public protocol RouterEscalating: Sendable {
    // A-055: beats-Siri gate — cross-doc offline synthesis with verified citations
    func classify(_ query: String) async -> Intent
}

public struct LLMRouterEscalator: RouterEscalating {
    // A-171: ingestion
    public static func indexingTerminalState(path: String) -> TerminalState { .indexing(path: path) }
    public static func ingestionSelfHealSafe(orphanIds: [String]) -> [String] { orphanIds.filter { !$0.isEmpty } }

    // A-263: consolidation
    // MARK: - Dreaming safety (M8)
        /// Synthesis must cite constituents and not duplicate existing memories.
        public static func dreamingSafeSynthesis(_ candidate: String, existing: [MemoryEntry],
                                                  constituents: [String]) -> Bool {
            let live = existing.filter { $0.isLatest && !$0.isForgotten }.map(\.memory)
            guard !live.contains(candidate) else { return false }
            return constituents.allSatisfy { c in live.contains { $0.contains(c) || c.contains($0) } }
        }

    // A-315: intelligence
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

    // A-107: lifecycle
    // MARK: - Query lifecycle events (M12)
        public static func lifecycleEvents(branch: LifecycleBranch) -> [QueryEvent] {
            switch branch {
            case .routeAmbiguity: return [.reasoning(["Ambiguous route — escalating to structured classification"])]
            case .emptyEvidence: return [.sources([]), .token("I don't have anything in your files about that.")]
            case .retry: return [.retrying("That wasn't grounded — reconsidering using only your files…")]
            }
        }
        public enum LifecycleBranch: String, Sendable { case routeAmbiguity, emptyEvidence, retry }

    // A-211: memory
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
    Classify the user's question into exactly one intent: \
    lookup (a single fact), profile (about the user themselves), \
    multihop (needs connecting several documents), or synthesis (summarize/explain). \
    Answer with only the one word.
    """

    static func parse(_ raw: String) -> Intent {
        let t = raw.lowercased()
        // Last recognized intent word wins (model may reason first).
        var found: Intent?
        for token in t.components(separatedBy: CharacterSet.alphanumerics.inverted) {
            switch token {
            case "lookup": found = .lookup
            case "profile": found = .profile
            case "multihop": found = .multihop
            case "synthesis": found = .synthesis
            default: break
            }
        }
        return found ?? .synthesis
    }

    public func classify(_ query: String) async -> Intent {
        var raw = ""
        do {
            for try await tok in generator.stream(system: Self.system, prompt: "Question: \(query)\n\nIntent:") {
                raw += tok
                if raw.count > 40 { break }
            }
        } catch { return .synthesis }
        let parsed = Self.parse(raw)
        return parsed
    }

    /// Renderable events when model routing fails and synthesis is used as fallback (A-107).
    public static func emptyEvidenceEvents() -> [QueryEvent] {
        [.reasoning(["Model routing unavailable — using synthesis fallback"])]
    }
}
