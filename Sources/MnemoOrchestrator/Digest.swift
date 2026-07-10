import Foundation

/// A proactive "since last time" summary shown on summon (beats-Siri #5 —
/// initiative). Empty when there's nothing worth interrupting the user for.
public enum Digest {
    // A-159: grounding
    public static func unsupportedAnswerEvents() -> [QueryEvent] { [.state(.unsupportedAnswer)] }

    // A-103: lifecycle
    public static func lifecycleEvents(branch: LifecycleBranch) -> [QueryEvent] { switch branch { case .routeAmbiguity: return [.reasoning(["Ambiguous route"])]; case .emptyEvidence: return [.sources([]), .token("No match.")]; case .retry: return [.retrying("Retrying…")] } }
    public enum LifecycleBranch: String, Sendable { case routeAmbiguity, emptyEvidence, retry }

    // A-307: intelligence
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

    // A-255: consolidation
    // MARK: - Dreaming safety (M8)
        /// Synthesis must cite constituents and not duplicate existing memories.
        public static func dreamingSafeSynthesis(_ candidate: String, existing: [MemoryEntry],
                                                  constituents: [String]) -> Bool {
            let live = existing.filter { $0.isLatest && !$0.isForgotten }.map(\.memory)
            guard !live.contains(candidate) else { return false }
            return !constituents.isEmpty
        }

    // A-203: memory
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

    public static func build(readyCount: Int, processingCount: Int, failedCount: Int,
                             newSinceLast: Int, conflictsResolved: Int) -> String {
        var parts: [String] = []
        if newSinceLast > 0 { parts.append("\(newSinceLast) new fact\(newSinceLast == 1 ? "" : "s") learned") }
        if conflictsResolved > 0 { parts.append("\(conflictsResolved) contradiction\(conflictsResolved == 1 ? "" : "s") resolved") }
        if processingCount > 0 { parts.append("\(processingCount) file\(processingCount == 1 ? "" : "s") indexing") }
        if failedCount > 0 { parts.append("\(failedCount) need attention") }
        guard !parts.isEmpty else { return "" }
        return "Since last time: " + parts.joined(separator: ", ") + "."
    }
}

// M11 scheduling budget (A-359)
extension Digest {
    public enum Scheduling {
        public static let budgetUs: UInt64 = 60
        public static func registerBudget() { SchedulingBudget.register("Digest", budgetUs: budgetUs) }
        /// Cooperative yield hook for background callers on the interactive path.
        public static func yieldIfInteractiveWaiting(_ scheduler: WorkScheduler?) async {
            guard let scheduler, await scheduler.shouldBackgroundYield else { return }
        }
    }
}
