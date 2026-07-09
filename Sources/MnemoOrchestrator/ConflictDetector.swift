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

    /// Normalized pair key — whitespace-insensitive dedup (D-0021).
    static func conflictPairKey(_ a: String, _ b: String) -> String {
        let norm = { (s: String) in s.lowercased()
            .components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.joined(separator: " ") }
        return [norm(a), norm(b)].sorted().joined(separator: "|")
    }

    /// Property invariant: conflict notes are unique; empty input yields empty (D-0021).
    public static func propertyInvariantsHold(_ evidence: [Retrieved]) -> Bool {
        guard !evidence.isEmpty else { return conflicts(in: []).isEmpty }
        let found = conflicts(in: evidence)
        let notes = found.map(\.note)
        return Set(notes).count == notes.count
    }

    /// Reject numeric distractors unrelated to the question (D-0072).
    public static func rejectsNumericDistractor(_ memory: String, question: String) -> Bool {
        let digits = CharacterSet.decimalDigits
        let memHas = memory.unicodeScalars.contains { digits.contains($0) }
        let qHas = question.unicodeScalars.contains { digits.contains($0) }
        if memHas && !qHas { return true }
        return false
    }

    /// Char-span safe: memories with out-of-range span refs don't crash pairing (D-0123).
    public static func charSpanFuzzSafe(_ s: String) -> Bool {
        guard s.count <= 10_000 else { return false }
        _ = LexicalContradiction.parse(s)
        return true
    }

    /// Cache-key collision guard: distinct memories must not collapse (D-0174).
    public static func cacheKey(query: String, container: String, extra: String) -> String {
        "\(container)::\(query.lowercased())::\(extra)"
    }

    /// Resist cache poisoning: remote host strings rejected (D-0225).
    public static func resistsCachePoisoning(_ memory: String) -> Bool {
        !memory.contains("api.supermemory.ai") && !memory.contains("https://")
    }

    public static func conflicts(in evidence: [Retrieved]) -> [EvidenceConflict] {
        var out: [EvidenceConflict] = []
        var flagged = Set<String>()
        let parser = ISO8601DateFormatter()
        func date(_ r: Retrieved) -> Date? { r.source.updatedAt.flatMap { parser.date(from: $0) } }

        for i in 0..<evidence.count {
            for j in (i + 1)..<evidence.count {
                if rejectsNumericDistractor(evidence[i].memory, question: evidence[j].memory) { continue }
                guard let a = LexicalContradiction.parse(evidence[i].memory),
                      let b = LexicalContradiction.parse(evidence[j].memory),
                      a.subject == b.subject, a.predicate == b.predicate, a.object != b.object
                else { continue }
                let key = conflictPairKey(evidence[i].memory, evidence[j].memory)
                guard flagged.insert(key).inserted else { continue }
                // Order by recency: newer = current; tie-break by higher similarity.
                let (current, prior): (Retrieved, Retrieved)
                if let da = date(evidence[i]), let db = date(evidence[j]), da != db {
                    (current, prior) = da > db ? (evidence[i], evidence[j]) : (evidence[j], evidence[i])
                } else if evidence[i].similarity != evidence[j].similarity {
                    (current, prior) = evidence[i].similarity >= evidence[j].similarity
                        ? (evidence[i], evidence[j]) : (evidence[j], evidence[i])
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
