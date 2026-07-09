import Foundation

/// How firmly a source (or answer) is grounded — expressed to the user as
/// relevance bars and a framing line (#4, #10).
public enum ConfidenceLevel: Int, Equatable, Sendable, Comparable {
    case low = 0, medium = 1, high = 2
    public static func < (a: ConfidenceLevel, b: ConfidenceLevel) -> Bool { a.rawValue < b.rawValue }

    public static func forSimilarity(_ sim: Double) -> ConfidenceLevel {
        switch sim {
        case 0.7...: return .high
        case 0.45..<0.7: return .medium
        default: return .low
        }
    }
}

public enum Confidence {
    /// Overall answer confidence: strong retrieval AND strong grounding.
    /// An unsupported answer is low no matter how similar the sources looked.
    public static func overall(topSimilarity: Double, supportedRatio: Double) -> ConfidenceLevel {
        if supportedRatio <= 0 { return .low }
        let sim = ConfidenceLevel.forSimilarity(topSimilarity)
        if sim == .high && supportedRatio >= 0.75 { return .high }
        if sim == .low && supportedRatio < 0.5 { return .low }
        return .medium
    }

    /// Honest framing sentence for the answer header.
    public static func framing(_ level: ConfidenceLevel, sourceCount: Int) -> String {
        let src = sourceCount == 1 ? "1 source" : "\(sourceCount) sources"
        switch level {
        case .high: return "Grounded in \(src)."
        case .medium: return "Based on \(src) — check the citations."
        case .low: return "Loosely inferred; I'm not confident this is in your files."
        }
    }
}
