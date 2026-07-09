import Foundation

/// Rewrites a vague question into a stronger retrieval query (intelligence #2).
public protocol QueryRewriting: Sendable {
    func rewrite(_ query: String) async -> String
}

/// Local-model rewriter with a safe fallback to the original query.
public struct LLMQueryRewriter: QueryRewriting {
    let generator: Generating
    public init(generator: Generating) { self.generator = generator }

    static let system = """
    Rewrite the user's question into a concise search query that maximizes recall \
    over a personal document store: keep the key nouns/entities, drop filler, expand \
    obvious abbreviations. Output ONLY the rewritten query, nothing else.
    """

    /// Extract the rewrite from model output; fall back to the original if the
    /// output is empty, hedging, or implausibly long.
    static func parse(_ raw: String, original: String) -> String {
        var line = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: "\n").first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if let colon = line.range(of: "ewritten:") { line = String(line[colon.upperBound...]).trimmingCharacters(in: .whitespaces) }
        line = line.trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
        let hedges = ["i'm not sure", "could you", "clarify", "i don't", "please provide"]
        if line.isEmpty || line.count > 200 || hedges.contains(where: { line.lowercased().contains($0) }) {
            return original
        }
        return line
    }

    public func rewrite(_ query: String) async -> String {
        var raw = ""
        do {
            for try await tok in generator.stream(system: Self.system, prompt: "Question: \(query)\n\nRewritten query:") {
                raw += tok
                if raw.count > 240 { break }
            }
        } catch { return query }
        return Self.parse(raw, original: query)
    }
}
