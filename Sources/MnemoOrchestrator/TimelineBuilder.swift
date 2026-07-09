import Foundation

/// Reconstructs a chronological timeline from dated evidence (beats-Siri #3 —
/// temporal reasoning over your notes). Orders by the source's learned date,
/// falling back to the original order when dates are absent.
public enum TimelineBuilder {
    public static func build(from evidence: [Retrieved]) -> [Retrieved] {
        let parser = ISO8601DateFormatter()
        func date(_ r: Retrieved) -> Date? { r.source.updatedAt.flatMap { parser.date(from: $0) } }
        // Stable sort: dated items ascending; undated keep relative position.
        return evidence.enumerated().sorted { a, b in
            switch (date(a.element), date(b.element)) {
            case let (.some(da), .some(db)): return da != db ? da < db : a.offset < b.offset
            case (.some, .none): return true
            case (.none, .some): return false
            default: return a.offset < b.offset
            }
        }.map(\.element)
    }
}
