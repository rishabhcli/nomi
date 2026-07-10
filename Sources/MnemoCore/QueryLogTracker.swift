import Foundation

/// Accumulates query-path observability during a single `ask()` lifecycle.
/// Emits one JSON line via `QueryLogSink` — no document body at info level.
public struct QueryLogTracker: Sendable {
    public private(set) var entry: QueryLogEntry
    private let startedAt: Date
    private var hopCount = 0
    private var verified = 0
    private var checked = 0
    private var contextTokens = 0

    public init(queryId: String = UUID().uuidString, modelId: String? = nil, level: String = "info") {
        self.entry = QueryLogEntry(queryId: queryId, level: level)
        self.startedAt = Date()
        if let modelId { entry.modelId = modelId }
    }

    public mutating func noteRouted(intent: String, effort: String) {
        entry.routeIntent = intent
        entry.effortTier = effort
    }

    public mutating func noteFirstToken() {
        if entry.firstTokenMs == nil {
            entry.firstTokenMs = Int(Date().timeIntervalSince(startedAt) * 1000)
        }
    }

    public mutating func noteReasoningStep() { hopCount += 1 }

    public mutating func noteCitation(supported: Bool) {
        checked += 1
        if supported { verified += 1 }
    }

    public mutating func noteTerminal(_ state: String) {
        entry.terminalState = state
    }

    public mutating func noteContextTokens(_ count: Int) {
        contextTokens = count
    }

    public mutating func finalize(egressBlockedCount: Int = 0) -> QueryLogEntry {
        entry.retrievalHopCount = hopCount
        entry.totalMs = Int(Date().timeIntervalSince(startedAt) * 1000)
        entry.egressBlockedCount = egressBlockedCount
        entry.contextTokenCount = contextTokens > 0 ? contextTokens : nil
        if checked > 0 {
            entry.verificationPassRate = Double(verified) / Double(checked)
        }
        return entry.redacted()
    }

    public mutating func emit(to sink: QueryLogSink, egressBlockedCount: Int = 0) async {
        let final = finalize(egressBlockedCount: egressBlockedCount)
        await sink.emit(final)
    }
}

/// Test sink — captures emitted entries in memory (MnemoCoreTests).
public actor InMemoryQueryLogSink: QueryLogSink {
    public private(set) var entries: [QueryLogEntry] = []

    public init() {}

    public func emit(_ entry: QueryLogEntry) async {
        entries.append(entry)
    }

    public func last() -> QueryLogEntry? { entries.last }
}

/// Builds a sink from mnemo.toml `[logging]` — respects level and rotation.
public enum QueryLogSinkFactory {
    public static func make(config: MnemoConfig.Logging) -> QueryLogSink {
        switch config.level.lowercased() {
        case "off", "none":
            return NullQueryLogSink()
        default:
            return FileQueryLogSink(path: MnemoLogPaths.appJSONL, rotationMb: config.rotationMb)
        }
    }
}
