// A-014 audit: no info-level logging in this file — document text flows only
// into composed prompts for generation, never into log output.
// Verified: no Logger/os_log calls; context() formats evidence for the model only.

public enum Prompt {
    // A-126: grounding
    public static func citationIntegritySupported(_ s: String, evidence: [Retrieved]) -> Bool {
        GroundingCheck.citationIntegritySupported(s, evidence: evidence)
    }
    public static func unsupportedAnswerEvents() -> [QueryEvent] { GroundingCheck.unsupportedAnswerEvents() }

    // A-326: latency
    // MARK: - Scheduling (M11)
        /// Interactive queries preempt utility background work at chunk boundaries.
        public static func schedulingYieldHint(priority: WorkPriority = .background) -> Bool {
            priority < .interactive
        }

    // A-182: ingestion
    public static func indexingTerminalState(path: String) -> TerminalState { .indexing(path: path) }
    public static func ingestionSelfHealSafe(orphanIds: [String]) -> [String] { orphanIds.filter { !$0.isEmpty } }

    // A-274: consolidation
    // MARK: - Dreaming safety (M8)
        /// Synthesis must cite constituents and not duplicate existing memories.
        public static func dreamingSafeSynthesis(_ candidate: String, existing: [MemoryEntry],
                                                  constituents: [String]) -> Bool {
            let live = existing.filter { $0.isLatest && !$0.isForgotten }.map(\.memory)
            guard !live.contains(candidate) else { return false }
            return constituents.allSatisfy { c in live.contains { $0.contains(c) || c.contains($0) } }
        }

    // A-118: lifecycle
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

    // A-222: memory
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

    public static let system = """
    You are Mnemo, an on-device assistant. Answer only from the provided context. \
    Attach the source document title to each claim, citing it inline like [title]. \
    If the context does not contain the answer, say so plainly — do not invent facts. \
    Keep answers short; add structure only when the answer is genuinely multi-part.
    """

    /// Full system message for one query: profile preamble + reasoning effort +
    /// the generation contract (PLAN.md M4) + an optional formatting directive
    /// (answer shape + tone, expressive #1/#2). gpt-oss reads the effort line.
    public static func compose(preamble: String, effort: String, style: String = "") -> String {
        let styleLine = style.isEmpty ? "" : "\nFormat: \(style)\n"
        return """
        \(preamble)

        Reasoning: \(effort) effort.
        \(styleLine)
        \(system)
        """
    }

    /// Recent conversation turns, prepended so follow-ups ("why?", "the second
    /// one?") have context. Kept short to preserve the evidence budget.
    public static func conversation(_ history: [Turn]) -> String {
        let recent = history.suffix(3)
        guard !recent.isEmpty else { return "" }
        let block = recent.map { "Q: \($0.question)\nA: \($0.answer)" }.joined(separator: "\n")
        return "Earlier in this conversation:\n\(block)\n\n"
    }

    public static func context(_ hits: [Retrieved]) -> String {
        guard !hits.isEmpty else { return "NO CONTEXT AVAILABLE." }
        return hits.map { h in
            let span: String
            if let s = h.source.charStart, let e = h.source.charEnd {
                span = " @\(s)-\(e)"
            } else {
                span = ""
            }
            let idTag = h.source.docId.isEmpty ? "" : " id:\(h.source.docId)"
            return "[source: \(h.source.title) — \(h.source.path)\(idTag)\(span)]\n\(h.memory)"
        }.joined(separator: "\n\n")
    }

    /// Collision-resistant answer cache key — includes evidence fingerprint.
    public static func answerCacheKey(query: String, container: String, corpusVersion: Int,
                                      evidence: [Retrieved]) -> String {
        let q = query.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let fp = evidence.map { "\($0.source.docId):\($0.memory.prefix(48))" }.sorted().joined(separator: "|")
        var h: UInt64 = UInt64(bitPattern: Int64(corpusVersion))
        for byte in (container + "|" + q + "|" + fp).utf8 {
            h ^= UInt64(byte)
            h &*= 0x9E37_79B9_7F4A_7C15
        }
        return String(format: "%016llx", h)
    }
}
