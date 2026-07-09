import Foundation

/// Work priority (PLAN.md M11): interactive generation preempts retrieval,
/// which preempts background indexing & dreaming.
public enum WorkPriority: Int, Sendable, Comparable {
    case background = 0, retrieval = 1, interactive = 2
    public static func < (a: WorkPriority, b: WorkPriority) -> Bool { a.rawValue < b.rawValue }
}

/// Protects the interactive path: background work checks `shouldBackgroundYield`
/// and pauses/abandons when a live query is in flight. Cooperative preemption —
/// background tasks are chunked and yield at chunk boundaries.
public actor WorkScheduler {
    public struct Token: Equatable, Sendable { let id: UUID }
    private var interactiveInFlight = 0

    public init() {}

    public func beginInteractive() -> Token {
        interactiveInFlight += 1
        return Token(id: UUID())
    }
    public func endInteractive(_ token: Token) {
        interactiveInFlight = max(0, interactiveInFlight - 1)
    }

    /// True whenever any interactive query is running — the preemption signal.
    public var shouldBackgroundYield: Bool { interactiveInFlight > 0 }

    /// Runs interactive work with lifecycle tracking so background yields.
    public func runInteractive<T: Sendable>(_ op: @Sendable () async throws -> T) async rethrows -> T {
        let token = beginInteractive()
        defer { endInteractive(token) }
        return try await op()
    }

    /// Runs a chunked background job, abandoning remaining chunks the moment an
    /// interactive query arrives (bounded preemption window = one chunk).
    public func runBackgroundChunked(total: Int, _ chunk: @Sendable (Int) async -> Void) async {
        for i in 0..<total {
            if shouldBackgroundYield { return }   // interactive arrived → abandon the rest
            await chunk(i)
        }
    }
}
