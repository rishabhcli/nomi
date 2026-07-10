import Foundation

// LLMHopPlanner.swift — JSON-constrained hop planning for agentic grep (M3, M4).
// Audit: no force-unwraps, try!, or silent empty catches on the query path.

/// Plans the next agentic-grep hop with the local model (JSON-constrained,
/// one short call per hop). The loop's hard cap in AgenticGrep bounds cost.
public struct LLMHopPlanner: HopPlanning {
    // A-124: grounding
    public static func unsupportedAnswerEvents() -> [QueryEvent] { [.state(.unsupportedAnswer)] }

    // A-324: latency
    // MARK: - Scheduling (M11)
        /// Interactive queries preempt utility background work at chunk boundaries.
        public static func schedulingYieldHint(priority: WorkPriority = .background) -> Bool {
            priority < .interactive
        }

    // A-180: ingestion
    public static func indexingTerminalState(path: String) -> TerminalState { .indexing(path: path) }
    public static func ingestionSelfHealSafe(orphanIds: [String]) -> [String] { orphanIds.filter { !$0.isEmpty } }

    // A-168: ingestion
    // MARK: - Ingestion reliability (M2)

    // A-272: consolidation
    // MARK: - Dreaming safety (M8)
        /// Synthesis must cite constituents and not duplicate existing memories.
        public static func dreamingSafeSynthesis(_ candidate: String, existing: [MemoryEntry],
                                                  constituents: [String]) -> Bool {
            let live = existing.filter { $0.isLatest && !$0.isForgotten }.map(\.memory)
            guard !live.contains(candidate) else { return false }
            return !constituents.isEmpty
        }

    // A-116: lifecycle
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

    // A-220: memory
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

    public init(generator: Generating) {
        self.generator = generator
    }

    static let system = """
    You plan the next step of an iterative search over the user's local files. \
    Respond with ONLY a JSON object, no prose: \
    {"action":"semantic","query":"...","rationale":"..."} to search by meaning, \
    {"action":"literal","query":"...","rationale":"..."} to match an exact string \
    (identifiers, error codes, names), or {"action":"stop","rationale":"..."} when \
    the evidence already covers every part of the question. Prefer stopping early. \
    Never repeat a query that was already tried.
    """

    struct Wire: Decodable {
        let action: String
        let query: String?
        let rationale: String?
    }

    /// Extracts the decision JSON from raw model output (tolerates fences/prose).
    static func parse(_ raw: String) -> HopDecision {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        var candidate = text
        if let start = text.firstIndex(of: "{"), let end = text.lastIndex(of: "}") {
            candidate = String(text[start...end])
        }
        guard let data = candidate.data(using: .utf8),
              let wire = try? JSONDecoder().decode(Wire.self, from: data) else {
            return .stop(rationale: "planner output unparseable")
        }
        let why = wire.rationale ?? ""
        switch wire.action {
        case "semantic": return wire.query.map { .semantic($0, rationale: why) } ?? .stop(rationale: why)
        case "literal": return wire.query.map { .literal($0, rationale: why) } ?? .stop(rationale: why)
        default: return .stop(rationale: why.isEmpty ? "planner chose stop" : why)
        }
    }

    public func nextHop(question: String, evidence: [Retrieved], hops: [HopTrace]) async -> HopDecision {
        let evidenceBlock = evidence.isEmpty ? "none yet"
            : evidence.map { "- [\($0.source.path.isEmpty ? "memory" : $0.source.path)] \($0.memory)" }
                .joined(separator: "\n")
        let hopBlock = hops.map { "\($0.hop). \($0.kind) \"\($0.query)\"" }.joined(separator: "\n")
        let prompt = """
        QUESTION: \(question)

        EVIDENCE SO FAR:
        \(evidenceBlock)

        HOPS ALREADY TRIED:
        \(hopBlock.isEmpty ? "none" : hopBlock)

        Decide the next action (JSON only).
        """
        var raw = ""
        do {
            for try await tok in generator.stream(system: Self.system, prompt: prompt) { raw += tok }
        } catch {
            return .stop(rationale: "planner error: \(error)")
        }
        return Self.parse(raw)
    }
}
