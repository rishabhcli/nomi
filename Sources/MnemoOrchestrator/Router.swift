import Foundation

/// Query intent (PLAN.md M4). Raw values match the labeled routing set.
public enum Intent: String, Equatable, Sendable {
    case lookup, profile, synthesis, multihop
}

public struct RoutingResult: Equatable, Sendable {
    public let intent: Intent
    public let ambiguous: Bool   // true → escalate to the structured model call
}

public protocol QueryRouter: Sendable {
    func classify(_ q: String) -> RoutingResult
}

/// Fast lexical router. The common path pays no model round-trip; only
/// genuinely ambiguous queries set `ambiguous` for escalation (M4 Task 1).
public struct HeuristicRouter: QueryRouter {
    public init() {}

    static let multihopCues = [
        "compare", "contrast", "reconcile", "differ", "difference between",
        " vs ", " versus ", "across ", "how do ", "relate to", "evolve",
        "evolved", "trace how", "changed and why", " against ",
    ]
    static let profileCues = [
        "about me", "my usual", "usually", "my approach", "my preference",
        "preferences for", "my style", "my habit", "habits", "tend to",
        "normally", "typical", "what you know about", "my general", "my routine",
    ]
    static let lookupLeads = ["what is", "what's", "when did", "when is", "where is",
                              "where's", "who is", "who's", "which", "what year", "what time"]
    static let synthesisCues = ["summarize", "summary", "overview", "walk me through",
                                "explain", "describe", "tell me about", "recap",
                                "story behind", "what happened"]

    public func classify(_ q: String) -> RoutingResult {
        let s = " " + q.lowercased() + " "
        let hasMulti = Self.multihopCues.contains { s.contains($0) }
        let hasProfile = Self.profileCues.contains { s.contains($0) }
        let hasSynth = Self.synthesisCues.contains { s.contains($0) }
        let wordCount = q.split(whereSeparator: { $0 == " " }).count
        let looksLookup = Self.lookupLeads.contains { s.contains(" \($0) ") || s.hasPrefix(" \($0) ") }
            && wordCount <= 10

        // Multihop is the strongest signal (comparison across docs).
        if hasMulti {
            // A real comparison names two+ things; a very short one is too vague
            // to trust — escalate to the structured model call.
            return RoutingResult(intent: .multihop, ambiguous: wordCount <= 4)
        }
        if hasProfile {
            return RoutingResult(intent: .profile, ambiguous: false)
        }
        if hasSynth {
            return RoutingResult(intent: .synthesis, ambiguous: false)
        }
        if looksLookup {
            return RoutingResult(intent: .lookup, ambiguous: false)
        }
        // No strong cue → default to synthesis, and let the model arbitrate.
        return RoutingResult(intent: .synthesis, ambiguous: true)
    }
}

/// Reasoning-effort per path (config `[model.effort]`), PLAN.md M4 table.
public struct EffortPolicy: Equatable, Sendable {
    public let routing, extraction, synthesis, multihop: String
    public init(routing: String, extraction: String, synthesis: String, multihop: String) {
        self.routing = routing
        self.extraction = extraction
        self.synthesis = synthesis
        self.multihop = multihop
    }
    public func forIntent(_ intent: Intent) -> String {
        switch intent {
        case .multihop: return multihop
        case .lookup, .synthesis, .profile: return synthesis   // single-shot synthesis tier
        }
    }
}
