public enum Prompt {
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
            return "[source: \(h.source.title) — \(h.source.path)\(span)]\n\(h.memory)"
        }.joined(separator: "\n\n")
    }
}
