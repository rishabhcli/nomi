import Foundation

/// Query intent (PLAN.md M4). Raw values match the labeled routing set.
public enum Intent: String, Equatable, Sendable {
    // A-054: beats-Siri gate — cross-doc offline synthesis with verified citations
    case lookup, profile, synthesis, multihop
}

public struct RoutingResult: Equatable, Sendable {
    public let intent: Intent
    public let ambiguous: Bool   // true → escalate to the structured model call

    /// Lifecycle events when routing is ambiguous (A-106).
    public func ambiguityEvents() -> [QueryEvent] {
        guard ambiguous else { return [] }
        return [.reasoning(["Routing is ambiguous — escalating to the model"])]
    }
}

public protocol QueryRouter: Sendable {
    func classify(_ q: String) -> RoutingResult
}

/// Fast lexical router. The common path pays no model round-trip; only
/// genuinely ambiguous queries set `ambiguous` for escalation (M4 Task 1).
public struct HeuristicRouter: QueryRouter {
    // A-170: ingestion
    public static func indexingTerminalState(path: String) -> TerminalState { .indexing(path: path) }
    public static func ingestionSelfHealSafe(orphanIds: [String]) -> [String] { orphanIds.filter { !$0.isEmpty } }

    // A-262: consolidation
    // MARK: - Dreaming safety (M8)
        /// Synthesis must cite constituents and not duplicate existing memories.
        public static func dreamingSafeSynthesis(_ candidate: String, existing: [MemoryEntry],
                                                  constituents: [String]) -> Bool {
            let live = existing.filter { $0.isLatest && !$0.isForgotten }.map(\.memory)
            guard !live.contains(candidate) else { return false }
            return constituents.allSatisfy { c in live.contains { $0.contains(c) || c.contains($0) } }
        }

    // A-314: intelligence
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

    // A-106: lifecycle
    // MARK: - Query lifecycle events (M12)
        public static func lifecycleEvents(branch: LifecycleBranch) -> [QueryEvent] {
            switch branch {
            case .routeAmbiguity: return [.reasoning(["Ambiguous route — escalating to structured classification"])]
            case .emptyEvidence: return [.sources([]), .token("I don't have anything in your files about that.")]
            case .retry: return [.retrying("That wasn't grounded — reconsidering using only your files…")]
            }
        }
        public enum LifecycleBranch: String, Sendable { case routeAmbiguity, emptyEvidence, retry }

    // A-210: memory
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

    public init() {}

    static let multihopCues = [
        "compare", "contrast", "reconcile", "differ", "difference between",
        " vs ", " versus ", "across ", "how do ", "relate to", "evolve",
        "evolved", "trace how", "changed and why", " against ",
    ]
    static let profileCues = [
        "about me", "my usual", "usually", "my approach", "my preference",
        "preferences for", "my style", "my habit", "habits", "tend to",
        "normally", "typical", "what you know about", "my general", "my routine",
    ]
    static let lookupLeads = ["what is", "what's", "when did", "when is", "where is",
                              "where's", "who is", "who's", "which", "what year", "what time"]
    static let synthesisCues = ["summarize", "summary", "overview", "walk me through",
                                "explain", "describe", "tell me about", "recap",
                                "story behind", "what happened"]

    public func classify(_ q: String) -> RoutingResult {
        let s = " " + q.lowercased() + " "
        let hasMulti = Self.multihopCues.contains { s.contains($0) }
        let hasProfile = Self.profileCues.contains { s.contains($0) }
        let hasSynth = Self.synthesisCues.contains { s.contains($0) }
        let wordCount = q.split(whereSeparator: { $0 == " " }).count
        let looksLookup = Self.lookupLeads.contains { s.contains(" \($0) ") || s.hasPrefix(" \($0) ") }
            && wordCount <= 16

        // Multihop is the strongest signal (comparison across docs).
        if hasMulti {
            // A real comparison names two+ things; a very short one is too vague
            // to trust — escalate to the structured model call.
            return RoutingResult(intent: .multihop, ambiguous: wordCount <= 4)
        }
        if hasProfile {
            return RoutingResult(intent: .profile, ambiguous: false)
        }
        if hasSynth {
            return RoutingResult(intent: .synthesis, ambiguous: false)
        }
        if looksLookup {
            return RoutingResult(intent: .lookup, ambiguous: false)
        }
        // No strong cue → default to synthesis, and let the model arbitrate.
        return RoutingResult(intent: .synthesis, ambiguous: true)
    }
}

/// Reasoning-effort per path (config `[model.effort]`), PLAN.md M4 table.
public struct EffortPolicy: Equatable, Sendable {
    public let routing, extraction, synthesis, multihop: String
    public init(routing: String, extraction: String, synthesis: String, multihop: String) {
        self.routing = routing
        self.extraction = extraction
        self.synthesis = synthesis
        self.multihop = multihop
    }
    public func forIntent(_ intent: Intent) -> String {
        switch intent {
        case .multihop: return multihop
        case .lookup, .synthesis, .profile: return synthesis   // single-shot synthesis tier
        }
    }
}
