import Foundation

/// Splits a compound question into independently-retrievable sub-questions
/// (intelligence #10), so "what is X and when did Y" retrieves for both parts.
public enum QueryDecomposer {
    public static func split(_ query: String) -> [String] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        // Only split on " and " that joins two clause-like halves (each side has
        // enough words and at least one looks like a question/verb clause).
        let lower = q.lowercased()
        guard let range = lower.range(of: " and ") else { return [q] }
        let left = String(q[q.startIndex..<q.index(q.startIndex, offsetBy: lower.distance(from: lower.startIndex, to: range.lowerBound))])
        let rightStart = q.index(q.startIndex, offsetBy: lower.distance(from: lower.startIndex, to: range.upperBound))
        let right = String(q[rightStart...])

        func isClause(_ s: String) -> Bool {
            let words = s.split(separator: " ")
            guard words.count >= 3 else { return false }
            let verbs = ["is", "are", "was", "were", "did", "do", "does", "when", "how", "why",
                         "what", "where", "who", "adopt", "adopted", "switch", "use", "used", "have"]
            return words.contains { verbs.contains($0.lowercased()) }
        }
        let l = left.trimmingCharacters(in: .whitespaces)
        let r = right.trimmingCharacters(in: .whitespaces)
        guard isClause(l), isClause(r) else { return [q] }
        // Carry a trailing "?" onto the first half for readability.
        let lq = l.hasSuffix("?") ? l : l + "?"
        return [lq, r]
    }
}
