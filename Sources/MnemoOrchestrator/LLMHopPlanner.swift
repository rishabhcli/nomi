import Foundation

/// Plans the next agentic-grep hop with the local model (JSON-constrained,
/// one short call per hop). The loop's hard cap in AgenticGrep bounds cost.
public struct LLMHopPlanner: HopPlanning {
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
