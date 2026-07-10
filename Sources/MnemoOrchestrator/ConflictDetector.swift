import Foundation

// ConflictDetector.swift — evidence disagreement detection (M4, intelligence #5).
// Public entry points:
//   EvidenceConflict — human-readable conflict note
//   ConflictDetector.conflicts — find contradictory facts in evidence

/// A detected disagreement between two retrieved facts (intelligence #5).
public struct EvidenceConflict: Equatable, Sendable {
    public let note: String   // human-readable "your notes disagree…" line
}

/// Finds evidence that contradicts other evidence (same subject+predicate,
/// different object) and phrases it — preferring the more recent fact as
/// current, so the assistant reasons about consistency instead of guessing.
public enum ConflictDetector {
    // A-333: latency
    // MARK: - Scheduling (M11)
        /// Interactive queries preempt utility background work at chunk boundaries.
        public static func schedulingYieldHint(priority: WorkPriority = .background) -> Bool {
            priority < .interactive
        }

    // A-189: ingestion
    // MARK: - ingestion
        public static func indexingTerminalState(path: String) -> TerminalState { .indexing(path: path) }
        public static func ingestionSelfHealSafe(orphanIds: [String]) -> [String] { orphanIds.filter { !$0.isEmpty } }

    // A-177: ingestion
    // MARK: - Ingestion reliability (M2)

    // A-281: intelligence
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

    // A-229: memory
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

    public static func conflicts(in evidence: [Retrieved]) -> [EvidenceConflict] {
        var out: [EvidenceConflict] = []
        var flagged = Set<String>()
        let parser = ISO8601DateFormatter()
        func date(_ r: Retrieved) -> Date? { r.source.updatedAt.flatMap { parser.date(from: $0) } }

        for i in 0..<evidence.count {
            for j in (i + 1)..<evidence.count {
                guard let a = LexicalContradiction.parse(evidence[i].memory),
                      let b = LexicalContradiction.parse(evidence[j].memory),
                      a.subject == b.subject, a.predicate == b.predicate, a.object != b.object
                else { continue }
                let key = [evidence[i].memory, evidence[j].memory].sorted().joined()
                guard flagged.insert(key).inserted else { continue }
                // Order by recency: newer = current.
                let (current, prior): (Retrieved, Retrieved)
                if let da = date(evidence[i]), let db = date(evidence[j]) {
                    (current, prior) = da >= db ? (evidence[i], evidence[j]) : (evidence[j], evidence[i])
                } else {
                    (current, prior) = (evidence[i], evidence[j])
                }
                out.append(EvidenceConflict(
                    note: "Your notes disagree — most recently: “\(current.memory)” (earlier: “\(prior.memory)”)."))
            }
        }
        return out
    }
}
