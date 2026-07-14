import Foundation

/// Live query observability surfaced to the notch (M1).
///
/// Focused, UI-facing value types kept in the orchestrator module so the public
/// `QueryEvent` contract never leaks the MnemoCore logging entry (a
/// privacy/redaction concern). The mapping from `QueryLogTracker` is trivial.

/// One completed pipeline stage and how long it took — e.g. retrieve, generate,
/// verify. Rendered as the per-stage timeline in the reasoning trace.
public struct QueryStage: Equatable, Sendable {
    public let name: String
    public let elapsedMs: Int
    public init(name: String, elapsedMs: Int) {
        self.name = name
        self.elapsedMs = elapsedMs
    }
}

/// End-of-query metrics for the trust footer and trace. Mirrors the subset of
/// `QueryLogEntry` the surface renders (`egressBlockedCount` is the per-query
/// delta, not the process-cumulative count).
public struct QueryMetrics: Equatable, Sendable {
    public var firstTokenMs: Int?
    public var totalMs: Int?
    public var contextTokens: Int?
    public var verificationPassRate: Double?
    public var egressBlockedCount: Int
    public init(firstTokenMs: Int? = nil, totalMs: Int? = nil, contextTokens: Int? = nil,
                verificationPassRate: Double? = nil, egressBlockedCount: Int = 0) {
        self.firstTokenMs = firstTokenMs
        self.totalMs = totalMs
        self.contextTokens = contextTokens
        self.verificationPassRate = verificationPassRate
        self.egressBlockedCount = egressBlockedCount
    }
}

/// Content model for the always-on trust footer (M1 progressive live-trace):
/// "● 0 outbound · 0.4s · Grounded". Pure — the view styles the dot/color; this
/// decides the words and whether the run stayed clean.
public struct TrustFooter: Equatable, Sendable {
    public let egressText: String
    public let egressClean: Bool
    public let timeText: String?
    public let confidence: ConfidenceLevel?
    public let confidenceLabel: String?
    public init(egressText: String, egressClean: Bool, timeText: String?,
                confidence: ConfidenceLevel?, confidenceLabel: String?) {
        self.egressText = egressText
        self.egressClean = egressClean
        self.timeText = timeText
        self.confidence = confidence
        self.confidenceLabel = confidenceLabel
    }
}

public enum TrustFooterModel {
    /// Build the footer from per-query metrics + overall confidence. Egress is the
    /// per-query delta (0 is the truthful default before metrics arrive, since the
    /// stack is loopback-only). Confidence is only claimed once an answer exists.
    public static func make(metrics: QueryMetrics?, confidence: ConfidenceLevel,
                            hasAnswer: Bool) -> TrustFooter {
        let egress = metrics?.egressBlockedCount ?? 0
        let clean = egress == 0
        let conf = hasAnswer ? confidence : nil
        return TrustFooter(
            egressText: clean ? "0 outbound" : "\(egress) blocked",
            egressClean: clean,
            timeText: metrics?.totalMs.map(formatMs),
            confidence: conf,
            confidenceLabel: conf.map(label))
    }

    static func formatMs(_ ms: Int) -> String {
        ms < 1000 ? "\(ms)ms" : String(format: "%.1fs", Double(ms) / 1000)
    }

    static func label(_ level: ConfidenceLevel) -> String {
        switch level {
        case .high: return "Grounded"
        case .medium: return "Check citations"
        case .low: return "Low confidence"
        }
    }
}
