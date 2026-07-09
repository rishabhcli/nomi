import Foundation

/// Detects questions that need counting/aggregation/duration, and computes a
/// deterministic figure from the evidence to hand the model (beats-Siri #2 —
/// grounded arithmetic over your own files, not a guess).
public enum NumericReasoner {
    public static func isNumericQuestion(_ query: String) -> Bool {
        let q = query.lowercased()
        let cues = ["how many", "how long", "how much", "total", "count", "number of",
                    "duration", "how far apart", "sum of", "average"]
        return cues.contains { q.contains($0) }
    }

    /// If the evidence contains ≥2 dates, computes the span between the earliest
    /// and latest and phrases it (days + weeks) for the model to use verbatim.
    public static func durationNote(in evidence: [Retrieved]) -> String? {
        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue)
        var dates: [Date] = []
        for hit in evidence {
            let ns = hit.memory as NSString
            detector?.enumerateMatches(in: hit.memory, range: NSRange(location: 0, length: ns.length)) { m, _, _ in
                if let d = m?.date { dates.append(d) }
            }
        }
        guard dates.count >= 2 else { return nil }
        let sorted = dates.sorted()
        let days = Int((sorted.last!.timeIntervalSince(sorted.first!)) / 86400 + 0.5)
        guard days > 0 else { return nil }
        let weeks = Int(Double(days) / 7 + 0.5)
        let df = DateFormatter(); df.dateStyle = .medium
        return "Pre-computed from the dated facts: the full span from \(df.string(from: sorted.first!)) to \(df.string(from: sorted.last!)) is \(days) days (~\(weeks) week\(weeks == 1 ? "" : "s")). If the question asks for this duration, use this computed value — do not re-derive it."
    }
}
