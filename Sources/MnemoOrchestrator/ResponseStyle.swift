import Foundation

/// The shape an answer should take, inferred from the question. Drives both the
/// generation directive and how the surface renders (PLAN.md M4 "format = short
/// lead, structure only when genuinely multi-part").
public enum AnswerShape: Equatable, Sendable {
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
        if has(["timeline", "chronolog", "history of", "trace ", "evolve", "evolved", "over time", "sequence of"]) {
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
    public static func directive(shape: AnswerShape, tone: ResponseTone) -> String {
        let shapeText: String
        switch shape {
        case .definition: shapeText = "Answer with a single, crisp sentence — a definition, no preamble."
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
