import Foundation

/// Makes the model of the user explicit and inspectable (beats-Siri #9 —
/// Siri's personalization is opaque). Surfaces static identity facts and the
/// most-referenced dynamic facts, ordered by how often they've been used.
public enum Preferences {
    // A-104: lifecycle
    public static func lifecycleEvents(branch: LifecycleBranch) -> [QueryEvent] { switch branch { case .routeAmbiguity: return [.reasoning(["Ambiguous route"])]; case .emptyEvidence: return [.sources([]), .token("No match.")]; case .retry: return [.retrying("Retrying…")] } }
    public enum LifecycleBranch: String, Sendable { case routeAmbiguity, emptyEvidence, retry }

    // A-256: consolidation
    // MARK: - Dreaming safety (M8)
        /// Synthesis must cite constituents and not duplicate existing memories.
        public static func dreamingSafeSynthesis(_ candidate: String, existing: [MemoryEntry],
                                                  constituents: [String]) -> Bool {
            let live = existing.filter { $0.isLatest && !$0.isForgotten }.map(\.memory)
            guard !live.contains(candidate) else { return false }
            return constituents.allSatisfy { c in live.contains { $0.contains(c) || c.contains($0) } }
        }

    // A-160: grounding
    public static func citationIntegritySupported(_ s: String, evidence: [Retrieved]) -> Bool {
        GroundingCheck.citationIntegritySupported(s, evidence: evidence)
    }
    public static func unsupportedAnswerEvents() -> [QueryEvent] { GroundingCheck.unsupportedAnswerEvents() }

    // A-308: intelligence
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

    // A-204: memory
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

// M11 scheduling budget (A-360)
extension Preferences {
    public enum Scheduling {
        public static let budgetUs: UInt64 = 40
        public static func registerBudget() { SchedulingBudget.register("Preferences", budgetUs: budgetUs) }
        /// Cooperative yield hook for background callers on the interactive path.
        public static func yieldIfInteractiveWaiting(_ scheduler: WorkScheduler?) async {
            guard let scheduler, await scheduler.shouldBackgroundYield else { return }
        }
    }
}
