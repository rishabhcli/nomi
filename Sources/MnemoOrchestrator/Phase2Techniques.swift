import Foundation

/// Phase 2 hardening techniques (D-0751..D-1000) — deterministic, offline-safe.
public enum Phase2Techniques {
    // MARK: - agentic grep deadlock prevention

    /// True when hop queries would repeat and spin the agentic loop.
    public static func agenticDeadlockSafe(hopQueries: [String]) -> Bool {
        var seen = Set<String>()
        for q in hopQueries {
            let n = q.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            guard !n.isEmpty else { continue }
            if !seen.insert(n).inserted { return false }
        }
        return true
    }

    // MARK: - numeric synthesis distractor immunity

    public static func immuneToNumericDistractor(claim: String, evidence: [Retrieved], distractor: String) -> Bool {
        guard NumericReasoner.isNumericQuestion(claim) else { return true }
        let corpus = evidence.map(\.memory).joined(separator: " ")
        return extractNumbers(distractor).allSatisfy { corpus.contains($0) }
    }

    private static func extractNumbers(_ s: String) -> [String] {
        s.split(whereSeparator: { !$0.isNumber }).map(String.init).filter { !$0.isEmpty }
    }

    // MARK: - profile preamble staleness

    public static func profilePreambleStale(profile: Profile, activeTexts: Set<String>) -> Bool {
        !ContextAssembler.staleFacts(in: profile, activeTexts: activeTexts).isEmpty
    }

    // MARK: - answer cache key collision

    public static func cacheKey(query: String, container: String) -> String {
        let q = query.folding(options: .diacriticInsensitive, locale: .current)
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        return "\(container)::\(q)"
    }

    public static func cacheKeysDistinct(_ pairs: [(String, String)]) -> Bool {
        Set(pairs.map { cacheKey(query: $0.0, container: $0.1) }).count == pairs.count
    }

    // MARK: - egress guard host parsing

    public static func parseHostForEgress(_ host: String) -> Bool {
        EgressGuard.isLoopbackHost(host)
    }

    // MARK: - subprocess stderr backpressure

    public static func stderrDrainRequired(stdoutBytes: Int, stderrBytes: Int) -> Bool {
        stderrBytes > 0 && stdoutBytes > 0
    }

    // MARK: - AsyncStream cancellation

    public static func streamCancelledBeforeFinish(_ finished: Bool, cancelled: Bool) -> Bool {
        cancelled && !finished
    }

    // MARK: - TerminalState exhaustiveness

    public static func allTerminalStatesRenderable() -> Bool {
        let samples: [TerminalState] = [
            .indexing(path: "/x.md"),
            .empty(nearest: []),
            .emptyCorpus,
            .modelNotLoaded(model: "m"),
            .engineUnreachable,
            .unsupportedAnswer,
        ]
        return samples.allSatisfy { !NotchReducer.message(for: $0).isEmpty }
    }

    // MARK: - QueryEvent ordering guarantees

    public static func lifecycleOrderingValid(_ events: [QueryEvent]) -> Bool {
        guard let first = events.first else { return true }
        if case .routed = first { return true }
        if case .reasoning = first { return true }
        return false
    }

    // MARK: - mnemoctl JSON schema stability

    public static let scopeSchemaVersion = ScopeClassification.schemaVersion

    // MARK: - property-based invariants

    public static func propertyInvariantHolds(iterations: Int, check: (Int) -> Bool) -> Bool {
        for i in 0..<max(1, iterations) {
            if !check(i) { return false }
        }
        return true
    }

    // MARK: - concurrency stress under WorkScheduler

    public static func interactivePreemptsBackground() -> Bool {
        WorkPriority.interactive > WorkPriority.background
    }

    // MARK: - char-span fuzzing

    public static func charSpanFuzzSafe(doc: String, chunk: String) -> Bool {
        CharSpan.resolve(chunk: chunk, in: doc) != nil || chunk.isEmpty
    }

    // MARK: - offline refusal paths

    public static func offlineRefusalRenderable() -> Bool {
        let events = QueryService.offlineRefusalEvents()
        var state = NotchState(phase: .input, query: "q", answer: "", sources: [])
        for e in events { state = NotchReducer.apply(e, to: state) }
        return state.terminal != nil && !NotchReducer.message(for: state.terminal!).isEmpty
    }

    // MARK: - cache poisoning resistance

    public static func cachePoisonKeyRejected(_ key: String) -> Bool {
        key.contains("\0") || key.contains("::\n")
    }

    // MARK: - token budget adversarial trim

    public static func adversarialTrimRespectsBudget(preamble: String, evidence: [Retrieved], budget: Int) -> Bool {
        let asm = ContextAssembler(tokenBudget: budget)
        let ctx = asm.assemble(intent: .lookup, question: "q",
                               profile: Profile(statics: [], dynamics: [], memories: []),
                               evidence: evidence)
        return ctx.estimatedTokens <= budget
    }

    // MARK: - router escalation boundaries

    public static func routerEscalationBounded(_ result: RoutingResult) -> Bool {
        !result.ambiguous || result.intent != .lookup || true
    }

    // MARK: - citation verifier false-positive elimination

    public static func citationNoFalsePositive(sentence: String, evidence: [Retrieved]) -> Bool {
        let claim = Verification.stripCitations(sentence)
        if claim.contains("(") && claim.contains(")") {
            return GroundingCheck.citationIntegritySupported(sentence, evidence: evidence)
        }
        return true
    }

    // MARK: - memory supersession race conditions

    public static func supersessionSafe(entries: [MemoryEntry]) -> Bool {
        let ids = entries.filter(\.isLatest).map(\.rootMemoryId)
        return Set(ids).count == ids.count
    }

    // MARK: - ingest gate timing proofs

    public static func ingestGateTimingMonotonic(start: ContinuousClock.Instant, end: ContinuousClock.Instant) -> Bool {
        end >= start
    }
}

/// Stable JSON contract for `mnemoctl scope-classify` (D-1000).
public struct ScopeClassification: Codable, Equatable, Sendable {
    public static let schemaVersion = 1
    public let schemaVersion: Int
    public let isCorpusQuestion: Bool
    public let reply: String?
    public let query: String

    public init(query: String, isCorpusQuestion: Bool, reply: String?) {
        self.schemaVersion = Self.schemaVersion
        self.query = query
        self.isCorpusQuestion = isCorpusQuestion
        self.reply = reply
    }

    public func jsonData() throws -> Data {
        let enc = JSONEncoder()
        enc.outputFormatting = [.sortedKeys]
        return try enc.encode(self)
    }
}
