import Foundation

/// Re-ranks evidence by a blend of semantic similarity, how often the user has
/// retrieved it (strength ledger), and recency (intelligence #7). Learns what
/// matters to this user rather than ranking on similarity alone.
public enum PersonalRanker {
    public static func rank(_ hits: [Retrieved], strength: [String: Int], now: Date = Date()) -> [Retrieved] {
        let maxStrength = max(1, strength.values.max() ?? 0)
        let parser = ISO8601DateFormatter()
        func score(_ h: Retrieved) -> Double {
            let sim = h.similarity                                    // 0…1
            let use = Double(strength[h.source.docId] ?? 0) / Double(maxStrength)   // 0…1
            var recency = 0.0
            if let iso = h.source.updatedAt, let d = parser.date(from: iso) {
                let ageDays = now.timeIntervalSince(d) / 86400
                recency = max(0, 1 - ageDays / 365)                  // decays over a year
            }
            // Similarity leads; usage and recency are lighter nudges.
            return sim * 0.7 + use * 0.2 + recency * 0.1
        }
        return hits.enumerated()
            .sorted { score($0.element) != score($1.element)
                ? score($0.element) > score($1.element) : $0.offset < $1.offset }
            .map(\.element)
    }
}
