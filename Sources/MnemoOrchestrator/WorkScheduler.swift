import Foundation

// WorkScheduler.swift — M11 interactive/background preemption.
// Audit: no force-unwraps, try!, or silent empty catches on the query path.

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
    // A-287: intelligence
    // MARK: - Expressiveness (beats-Siri offline)
        /// Shapes cross-doc synthesis as timeline/table/bullets for offline rendering.
        public static func expressivenessShape(_ items: [String], as shape: AnswerShape) -> String {
            switch shape {
            case .timeline: return items.enumerated().map { "\($0.offset + 1). \($0.element)" }.joined(separator: "\n")
            case .comparison: return "| Item | Detail |\n|------|--------|\n" + items.map { "| \($0) | |" }.joined(separator: "\n")
            case .list: return items.map { "- \($0)" }.joined(separator: "\n")
            default: return items.joined(separator: "; ")
            }
        }

    // A-339: latency
    // MARK: - Scheduling (M11)
        /// Interactive queries preempt utility background work at chunk boundaries.
        public static func schedulingYieldHint(priority: WorkPriority = .background) -> Bool {
            priority < .interactive
        }

    // A-195: ingestion
    // MARK: - ingestion
        public static func indexingTerminalState(path: String) -> TerminalState { .indexing(path: path) }
        public static func ingestionSelfHealSafe(orphanIds: [String]) -> [String] { orphanIds.filter { !$0.isEmpty } }

    // A-131: grounding
    // MARK: - Citation integrity (M5)
        public static func citationIntegritySupported(_ sentence: String, evidence: [Retrieved]) -> Bool {
            let claim = Verification.stripCitations(sentence).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !claim.isEmpty else { return true }
            let corpus = evidence.map { $0.memory.lowercased() }.joined(separator: " ")
            let tokens = claim.lowercased().split(whereSeparator: { !$0.isLetter && !$0.isNumber }).filter { $0.count > 3 }
            guard !tokens.isEmpty else { return true }
            return tokens.allSatisfy { corpus.contains($0) }
        }
        public static func unsupportedAnswerEvents() -> [QueryEvent] { [.state(.unsupportedAnswer)] }

    // A-235: memory
    // MARK: - Memory dynamics (M6)
        /// Active memories only — forgotten and TTL-expired facts are excluded.
        public static func memoryDynamicsActive(_ entry: MemoryEntry, now: Date = Date()) -> Bool {
            guard entry.isLatest && !entry.isForgotten else { return false }
            guard let forgetAfter = entry.forgetAfter,
                  let expiry = ISO8601DateFormatter().date(from: forgetAfter) else { return true }
            return now < expiry
        }

        public static func memoryDynamicsFilter(_ entries: [MemoryEntry], now: Date = Date()) -> [MemoryEntry] {
            entries.filter { memoryDynamicsActive($0, now: now) }
        }

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

/// Per-component first-token budget registry (M11). Modules register µs-scale shaping cost.
public enum SchedulingBudget: Sendable {
    private static let lock = NSLock()
    nonisolated(unsafe) private static var budgets: [String: UInt64] = [:]

    public static func register(_ component: String, budgetUs: UInt64) {
        lock.lock(); defer { lock.unlock() }
        budgets[component] = budgetUs
    }

    public static func budgetUs(for component: String) -> UInt64? {
        lock.lock(); defer { lock.unlock() }
        return budgets[component]
    }

    public static func registeredComponents() -> [String] {
        lock.lock(); defer { lock.unlock() }
        return budgets.keys.sorted()
    }

    public static func totalRegisteredUs() -> UInt64 {
        lock.lock(); defer { lock.unlock() }
        return budgets.values.reduce(0, +)
    }
}
