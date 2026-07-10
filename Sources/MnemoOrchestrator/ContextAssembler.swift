import Foundation

// ContextAssembler.swift — profile preamble + budget-trimmed evidence (M4).
// Invariant: constructs no network URLs; operates on in-memory Retrieved values only.

/// The assembled generation context: a persistent profile preamble plus
/// relevance-trimmed evidence, bounded by a token budget (PLAN.md M4).
public struct AssembledContext: Equatable, Sendable {
    public let preamble: String
    public let evidence: [Retrieved]
    public let tokenBudget: Int
    public var estimatedTokens: Int {
        TokenEstimate.of(preamble) + evidence.reduce(0) { $0 + TokenEstimate.of($1.memory) }
    }
}

/// Cheap, deterministic token estimate (~4 chars/token) — enough to bound
/// context without a tokenizer dependency.
public enum TokenEstimate {
    public static func of(_ s: String) -> Int { max(1, (s.count + 3) / 4) }
}

/// Builds context: profile as a system preamble, then reranked evidence,
/// trimming lowest-relevance first and capping the preamble so evidence
/// always gets a share of the budget.
public struct ContextAssembler: Sendable {
    // A-169: ingestion
    public static func indexingTerminalState(path: String) -> TerminalState { .indexing(path: path) }
    public static func ingestionSelfHealSafe(orphanIds: [String]) -> [String] { orphanIds.filter { !$0.isEmpty } }

    // A-125: grounding
    public static func unsupportedAnswerEvents() -> [QueryEvent] { [.state(.unsupportedAnswer)] }

    // A-325: latency
    // MARK: - Scheduling (M11)
        /// Interactive queries preempt utility background work at chunk boundaries.
        public static func schedulingYieldHint(priority: WorkPriority = .background) -> Bool {
            priority < .interactive
        }

    // A-181: ingestion

    // A-221: memory
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

    // A-273: consolidation
    // MARK: - Dreaming safety (M8)
        /// Synthesis must cite constituents and not duplicate existing memories.
        public static func dreamingSafeSynthesis(_ candidate: String, existing: [MemoryEntry],
                                                  constituents: [String]) -> Bool {
            let live = existing.filter { $0.isLatest && !$0.isForgotten }.map(\.memory)
            guard !live.contains(candidate) else { return false }
            return constituents.allSatisfy { c in live.contains { $0.contains(c) || c.contains($0) } }
        }

    // A-117: lifecycle
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

    let tokenBudget: Int
    let preambleFraction: Double   // max share of the budget the preamble may take

    public init(tokenBudget: Int, preambleFraction: Double = 0.5) {
        self.tokenBudget = tokenBudget
        self.preambleFraction = preambleFraction
    }

    public func assemble(intent: Intent, question: String,
                         profile: Profile, evidence: [Retrieved]) -> AssembledContext {
        let preamble = buildPreamble(profile, cap: Int(Double(tokenBudget) * preambleFraction))
        let remaining = max(0, tokenBudget - TokenEstimate.of(preamble))

        // Highest similarity first; keep while it fits. Profile memories are
        // query-relevant retrieval hits and must merge into the evidence pool.
        let ranked = (evidence + profile.memories).sorted { $0.similarity > $1.similarity }
        var kept: [Retrieved] = []
        var used = 0
        for hit in ranked {
            let cost = TokenEstimate.of(hit.memory)
            if used + cost > remaining { continue }   // skip; a smaller later hit may still fit
            kept.append(hit)
            used += cost
        }
        return AssembledContext(preamble: preamble, evidence: kept, tokenBudget: tokenBudget)
    }

    private func buildPreamble(_ profile: Profile, cap: Int) -> String {
        var lines = ["You are Mnemo. Here is what you already know about the user:"]
        var used = TokenEstimate.of(lines[0])
        func add(_ label: String, _ facts: [String]) {
            for fact in facts {
                let line = "- [\(label)] \(fact)"
                let cost = TokenEstimate.of(line)
                if used + cost > cap { return }
                lines.append(line)
                used += cost
            }
        }
        add("stable", profile.statics)
        add("current", profile.dynamics)
        if lines.count == 1 { lines.append("- (no profile facts yet)") }
        return lines.joined(separator: "\n")
    }
}
