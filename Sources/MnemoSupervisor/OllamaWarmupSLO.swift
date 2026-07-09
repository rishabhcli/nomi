import Foundation

/// Ollama warm-up SLO — model must be resident before interactive queries (M0/M11).
public enum OllamaWarmupSLO {
    public struct Report: Equatable, Sendable {
        public let model: String
        public let warmupMs: Int
        public let sloMs: Int
        public let passed: Bool

        public init(model: String, warmupMs: Int, sloMs: Int) {
            self.model = model
            self.warmupMs = warmupMs
            self.sloMs = sloMs
            self.passed = warmupMs <= sloMs
        }
    }

    /// Default warm-up budget: 60s on first bring-up (cold weights).
    public static let defaultSloMs = 60_000

    public static func evaluate(model: String, warmupMs: Int, sloMs: Int = defaultSloMs) -> Report {
        Report(model: model, warmupMs: warmupMs, sloMs: sloMs)
    }
}
