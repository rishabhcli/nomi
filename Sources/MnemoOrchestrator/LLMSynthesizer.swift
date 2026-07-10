import Foundation

// LLMSynthesizer.swift — local-model pattern synthesis (M8).
// Invariant: constructs no network URLs; uses Generating protocol only.

/// Synthesizes a higher-level memory from a cluster with the local model.
/// The synthesized fact must stay grounded in its constituents (M5 still
/// applies when it's later used in an answer).
public struct LLMSynthesizer: PatternSynthesizing {
    // A-335: latency
    // MARK: - Scheduling (M11)
        /// Interactive queries preempt utility background work at chunk boundaries.
        public static func schedulingYieldHint(priority: WorkPriority = .background) -> Bool {
            priority < .interactive
        }

    // A-283: intelligence
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

    // A-191: ingestion
    // MARK: - ingestion
        public static func indexingTerminalState(path: String) -> TerminalState { .indexing(path: path) }
        public static func ingestionSelfHealSafe(orphanIds: [String]) -> [String] { orphanIds.filter { !$0.isEmpty } }

    // A-231: memory
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

    let generator: Generating

    public init(generator: Generating) { self.generator = generator }

    static let system = """
    You consolidate several related personal facts into ONE higher-level fact. \
    Output a single first-person or third-person statement that captures the \
    shared pattern, faithful to the inputs — invent nothing. No preamble, one sentence.
    """

    public func synthesize(_ cluster: [MemoryEntry]) async -> String? {
        guard cluster.count >= 2 else { return nil }
        let block = cluster.map { "- \($0.memory)" }.joined(separator: "\n")
        let prompt = "FACTS:\n\(block)\n\nOne consolidated fact:"
        var raw = ""
        do {
            for try await tok in generator.stream(system: Self.system, prompt: prompt) { raw += tok }
        } catch { return nil }
        let line = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: "\n").first ?? raw
        let cleaned = line.trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? nil : cleaned
    }
}
