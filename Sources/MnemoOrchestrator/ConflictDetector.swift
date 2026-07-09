import Foundation

/// A detected disagreement between two retrieved facts (intelligence #5).
public struct EvidenceConflict: Equatable, Sendable {
    public let note: String   // human-readable "your notes disagree…" line
}

/// Finds evidence that contradicts other evidence (same subject+predicate,
/// different object) and phrases it — preferring the more recent fact as
/// current, so the assistant reasons about consistency instead of guessing.
public enum ConflictDetector {
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
