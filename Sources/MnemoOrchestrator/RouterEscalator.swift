import Foundation

/// Escalates an ambiguous heuristic-routing decision to a structured model
/// classification (intelligence #4, PLAN.md M4 Task 1).
public protocol RouterEscalating: Sendable {
    func classify(_ query: String) async -> Intent
}

public struct LLMRouterEscalator: RouterEscalating {
    let generator: Generating
    public init(generator: Generating) { self.generator = generator }

    static let system = """
    Classify the user's question into exactly one intent: \
    lookup (a single fact), profile (about the user themselves), \
    multihop (needs connecting several documents), or synthesis (summarize/explain). \
    Answer with only the one word.
    """

    static func parse(_ raw: String) -> Intent {
        let t = raw.lowercased()
        // Last recognized intent word wins (model may reason first).
        var found: Intent?
        for token in t.components(separatedBy: CharacterSet.alphanumerics.inverted) {
            switch token {
            case "lookup": found = .lookup
            case "profile": found = .profile
            case "multihop": found = .multihop
            case "synthesis": found = .synthesis
            default: break
            }
        }
        return found ?? .synthesis
    }

    public func classify(_ query: String) async -> Intent {
        var raw = ""
        do {
            for try await tok in generator.stream(system: Self.system, prompt: "Question: \(query)\n\nIntent:") {
                raw += tok
                if raw.count > 40 { break }
            }
        } catch { return .synthesis }
        return Self.parse(raw)
    }
}
