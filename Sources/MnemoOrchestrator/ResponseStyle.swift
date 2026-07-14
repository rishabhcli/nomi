import Foundation

// ResponseStyle.swift — answer shape and tone directives (M4).
// A-039 audit: no info-level logging of user document text.

/// The shape an answer should take, inferred from the question. Drives both the
/// generation directive and how the surface renders (PLAN.md M4 "format = short
/// lead, structure only when genuinely multi-part").
public enum AnswerShape: Equatable, Sendable {
    // A-091: lifecycle
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
    case definition   // crisp one-liner
    case comparison   // table / side-by-side
    case timeline     // chronological
    case list         // bullets
    case synthesis    // structured prose

    public static func detect(query: String, intent: Intent) -> AnswerShape {
        let q = " " + query.lowercased() + " "
        func has(_ cues: [String]) -> Bool { cues.contains { q.contains($0) } }

        if has(["compare", "comparison", " vs ", " versus ", "differ", "difference between", "contrast"]) {
            return .comparison
        }
        if has(["timeline", "chronolog", "history of", "trace ", "evolve", "evolved", "over time", "sequence of"])
            || (intent != .lookup && has(["when did", "when was"])) {
            return .timeline
        }
        if has(["list ", "what are ", "which ", "steps", "ways to", "options", "blockers"]) {
            return .list
        }
        if intent == .lookup, has(["what is", "what's", "who is", "who's", "define", "definition of"]) {
            return .definition
        }
        return .synthesis
    }
}

/// How expansive the answer should be (user-controllable via `/tone`).
public enum ResponseTone: String, Equatable, Sendable, CaseIterable {
    case brief, balanced, detailed
}

/// Composes the per-answer formatting directive appended to the system prompt.
public enum ResponseStyle {
    // A-151: grounding
    public static func unsupportedAnswerEvents() -> [QueryEvent] { [.state(.unsupportedAnswer)] }

    /// Test-support shim: forward to AnswerShape's lifecycle events (regression tests).
    public static func lifecycleEvents(branch: AnswerShape.LifecycleBranch) -> [QueryEvent] { AnswerShape.lifecycleEvents(branch: branch) }

    // A-247: consolidation
    // MARK: - Dreaming safety (M8)
        /// Synthesis must cite constituents and not duplicate existing memories.
        public static func dreamingSafeSynthesis(_ candidate: String, existing: [MemoryEntry],
                                                  constituents: [String]) -> Bool {
            let live = existing.filter { $0.isLatest && !$0.isForgotten }.map(\.memory)
            guard !live.contains(candidate) else { return false }
            return !constituents.isEmpty
        }

    // A-299: intelligence
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

    // A-143: grounding
    // MARK: - Citation integrity (M5)
        public static func citationIntegritySupported(_ sentence: String, evidence: [Retrieved]) -> Bool {
            let claim = Verification.stripCitations(sentence).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !claim.isEmpty else { return true }
            let corpus = evidence.map { $0.memory.lowercased() }.joined(separator: " ")
            let tokens = claim.lowercased().split(whereSeparator: { !$0.isLetter && !$0.isNumber }).filter { $0.count > 3 }
            guard !tokens.isEmpty else { return true }
            return tokens.allSatisfy { corpus.contains($0) }
        }

    public static func directive(shape: AnswerShape, tone: ResponseTone) -> String {
        let shapeText: String
        switch shape {
        case .definition:
            shapeText = "Answer with one crisp sentence containing one factual claim and one source title. Give only the core definition; do not append implementation details, examples, or a second clause."
        case .comparison: shapeText = "Format the answer as a compact Markdown table comparing the items, one row per dimension."
        case .timeline: shapeText = "Present the answer in chronological order as a dated bullet list (earliest first)."
        case .list: shapeText = "Answer as a short Markdown bullet list, one item per line."
        case .synthesis: shapeText = "Lead with a one-line takeaway, then add structure only if the answer is genuinely multi-part."
        }
        let toneText: String
        switch tone {
        case .brief: toneText = "Be as brief as possible — one sentence if you can."
        case .balanced: toneText = "Keep it concise but complete."
        case .detailed: toneText = "Be thorough: cover the relevant detail and nuance, still grounded only in the context."
        }
        return "\(shapeText) \(toneText)"
    }
}

/// The "here's what I understood" restatement shown while retrieving (#3).
public enum Understanding {
    public static func phrase(intent: Intent, sourceCount: Int) -> String {
        let verb: String
        switch intent {
        case .lookup: verb = "Looking up"
        case .profile: verb = "Recalling what I know"
        case .multihop: verb = "Connecting"
        case .synthesis: verb = "Reading"
        }
        if sourceCount <= 0 { return "\(verb) across your files…" }
        let noun = sourceCount == 1 ? "1 source" : "\(sourceCount) notes"
        return "\(verb) across \(noun)…"
    }
}

// M11 scheduling budget (A-351)
extension ResponseStyle {
    public enum Scheduling {
        public static let budgetUs: UInt64 = 50
        public static func registerBudget() { SchedulingBudget.register("ResponseStyle", budgetUs: budgetUs) }
        /// Cooperative yield hook for background callers on the interactive path.
        public static func yieldIfInteractiveWaiting(_ scheduler: WorkScheduler?) async {
            guard let scheduler, await scheduler.shouldBackgroundYield else { return }
        }
    }
}
