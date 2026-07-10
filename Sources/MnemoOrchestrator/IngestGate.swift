import Foundation

// IngestGate.swift — write-through ingest probe gate (M2).
// Audit: no force-unwraps, try!, or silent empty catches on the query path.

public struct IngestGate {
    // A-329: latency
    // MARK: - Scheduling (M11)
        /// Interactive queries preempt utility background work at chunk boundaries.
        public static func schedulingYieldHint(priority: WorkPriority = .background) -> Bool {
            priority < .interactive
        }

    // A-121: grounding
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

    // A-277: consolidation
    // MARK: - Dreaming safety (M8)
        /// Synthesis must cite constituents and not duplicate existing memories.
        public static func dreamingSafeSynthesis(_ candidate: String, existing: [MemoryEntry],
                                                  constituents: [String]) -> Bool {
            let live = existing.filter { $0.isLatest && !$0.isForgotten }.map(\.memory)
            guard !live.contains(candidate) else { return false }
            return !constituents.isEmpty
        }

    // A-225: memory
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

    let retriever: Retrieving
    public init(retriever: Retrieving) { self.retriever = retriever }

    public func writeFile(_ contents: String, to url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try contents.write(to: url, atomically: true, encoding: .utf8)
    }

    /// Polls search until the probe query returns any result, or the timeout elapses.
    public func waitUntilSearchable(probe query: String, timeout: Duration) async -> Bool {
        let deadline = ContinuousClock.now.advanced(by: timeout)
        while ContinuousClock.now < deadline {
            if let hits = try? await retriever.search(SearchRequest(q: query)), !hits.isEmpty { return true }
            try? await Task.sleep(for: .milliseconds(200))
        }
        return false
    }
}
