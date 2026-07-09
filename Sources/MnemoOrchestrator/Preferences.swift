import Foundation

/// Makes the model of the user explicit and inspectable (beats-Siri #9 —
/// Siri's personalization is opaque). Surfaces static identity facts and the
/// most-referenced dynamic facts, ordered by how often they've been used.
public enum Preferences {
    public static func summary(memories: [MemoryEntry], strength: [String: Int]) -> String {
        let live = memories.filter { $0.isLatest && !$0.isForgotten }
        guard !live.isEmpty else { return "I don't know your preferences yet — ask me things and I'll learn." }

        let statics = live.filter(\.isStatic).map(\.memory)
        let dynamics = live.filter { !$0.isStatic }
            .sorted { (strength[$0.id] ?? 0) > (strength[$1.id] ?? 0) }
            .prefix(5).map(\.memory)

        var lines: [String] = []
        if !statics.isEmpty { lines.append("About you: " + statics.prefix(5).joined(separator: "; ")) }
        if !dynamics.isEmpty { lines.append("You most often reference: " + dynamics.joined(separator: "; ")) }
        return lines.isEmpty ? "I'm still learning your preferences." : lines.joined(separator: "\n")
    }
}

/// Reconciles complementary/conflicting evidence into one attributed,
/// recency-aware statement (beats-Siri #10 — cross-document reconciliation).
public enum Reconciliation {
    public static func synthesize(_ evidence: [Retrieved]) -> String? {
        let conflicts = ConflictDetector.conflicts(in: evidence)
        guard let first = conflicts.first else { return nil }
        return first.note
    }
}
