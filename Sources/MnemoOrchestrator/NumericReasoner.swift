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

    /// If the evidence contains ≥2 dates, lists them chronologically and gives
    /// the earliest→latest span as an ADVISORY figure. It deliberately no longer
    /// forces the model to use the global min→max span verbatim: that span is
    /// only correct when the earliest and latest dated facts are the two events
    /// the question is actually about. When an unrelated date is present (e.g. an
    /// earlier kickoff, or a distractor date elsewhere in the corpus), the global
    /// span is wrong — so the model is told to pick the correct endpoints from
    /// context and compute from those.
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
        let chrono = sorted.map { df.string(from: $0) }.joined(separator: ", ")
        return "Dated facts found (chronological): \(chrono). The earliest→latest span is \(days) days (~\(weeks) week\(weeks == 1 ? "" : "s")). If the question asks for the interval between two specific events, identify the correct start and end dates from the evidence and compute from those — use the earliest→latest span only when those are the actual endpoints."
    }
}
