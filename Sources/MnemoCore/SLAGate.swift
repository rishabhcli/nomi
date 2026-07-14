import Foundation

/// SLA regression gates wired from mnemo.toml `[sla]` (platform observability).
public enum SLAGate {
    public struct Result: Equatable, Sendable {
        public let metric: String
        public let observedMs: Int
        public let limitMs: Int
        public let passed: Bool

        public init(metric: String, observedMs: Int, limitMs: Int) {
            self.metric = metric
            self.observedMs = observedMs
            self.limitMs = limitMs
            self.passed = observedMs <= limitMs
        }
    }

    public static func checkFirstToken(observedMs: Int, config: MnemoConfig) -> Result {
        Result(metric: "first_token_ms", observedMs: observedMs, limitMs: config.sla.firstTokenMs)
    }

    public static func checkSourcesRender(observedMs: Int, config: MnemoConfig) -> Result {
        Result(metric: "sources_render_ms", observedMs: observedMs, limitMs: config.sla.sourcesRenderMs)
    }

    /// P95 over samples — the hard regression guard trips at 2x the normal SLA.
    public static func p95(_ samplesMs: [Int]) -> Int {
        guard !samplesMs.isEmpty else { return 0 }
        let sorted = samplesMs.sorted()
        let idx = min(sorted.count - 1, Int(Double(sorted.count) * 0.95))
        return sorted[idx]
    }

    public static func regressionFailed(samplesMs: [Int], limitMs: Int) -> Bool {
        guard limitMs > 0 else { return true }
        return p95(samplesMs) >= limitMs * 2
    }
}
