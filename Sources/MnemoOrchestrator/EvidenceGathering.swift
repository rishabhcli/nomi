import Foundation

// A-004 audit: no info-level logging in this file — document text must never
// appear in logs. Evidence steps are human-readable labels only, not corpus content.

/// The evidence-gathering stage of the query lifecycle, split out of
/// QueryService: decompose → search → escalate → agentic → recall → time-filter.
/// Collects human-readable reasoning steps as it works (beats-Siri #1).
extension QueryService {
    /// Title given to hits recalled from the conversation space — used to mark
    /// them as secondary evidence (never fed to numeric reasoning, discounted
    /// in ranking).
    static let chatRecallTitle = "Earlier conversation"

    struct Gathered {
        let hits: [Retrieved]; let broadened: Bool; let decomposed: Bool; let steps: [String]
    }

    func gatherEvidence(_ q: String, intent: Intent) async throws -> Gathered {
        var steps: [String] = []
        // Compound-question decomposition (#10): retrieve for each sub-question.
        let subs = QueryDecomposer.split(q)
        let decomposed = subs.count > 1
        if decomposed { steps.append("Split into \(subs.count) sub-questions") }
        var merged: [Retrieved] = []
        var seen = Set<String>()
        for sub in subs {
            var hits = try await search(sub, mode: defaults.searchMode)
            if hits.isEmpty, defaults.searchMode == "memories" {
                hits = try await search(sub, mode: "hybrid")
            }
            for h in hits where seen.insert(dedupeKey(h)).inserted { merged.append(h) }

            // Engine document (chunk-level) search as a standing second
            // surface (#9): memories are distilled and can lag or miss a
            // document entirely — the top chunks carry the source text.
            if documentSearchEnabled, let docSearcher = retriever as? DocumentSearching {
                let chunkLimit = hits.isEmpty ? defaults.limit : 3
                let chunks = (try? await docSearcher.searchDocuments(sub, container: defaults.container, limit: chunkLimit)) ?? []
                var added = 0
                for h in chunks where seen.insert(dedupeKey(h)).inserted { merged.append(h); added += 1 }
                if added > 0, hits.isEmpty { steps.append("Used the engine's document search") }
            }
        }
        steps.append("Searched memory (\(merged.count) hits)")

        // Auto-escalation (#1): weak coverage → broaden before answering.
        var broadened = false
        let topSim = merged.map(\.similarity).max() ?? 0
        if Coverage.isWeak(topSimilarity: topSim, count: merged.count) {
            let broader = try await retriever.search(Coverage.escalate(SearchRequest(
                q: q, searchMode: defaults.searchMode, rerank: defaults.rerank,
                threshold: defaults.threshold, limit: defaults.limit, container: defaults.container)))
            if (broader.map(\.similarity).max() ?? 0) > topSim || (merged.isEmpty && !broader.isEmpty) {
                merged = broader
                broadened = true
                steps.append("Broadened the search (weak coverage)")
            }
        }

        // Agentic multi-hop (#1): follow the thread across files.
        if intent == .multihop, let agentic, let result = try? await agentic.run(q, scope: nil) {
            var added = 0
            for h in result.evidence where seen.insert(dedupeKey(h)).inserted { merged.append(h); added += 1 }
            if !result.hops.isEmpty { steps.append("Followed the thread across files (\(result.hops.count) hops, +\(added) evidence)") }
        }

        // Cross-session recall (beats-Siri #6): pull relevant prior conversation
        // turns from the dedicated chat space so it remembers earlier sessions.
        // Supplementary only — recalled chat can never be the sole "evidence"
        // (a junk query would otherwise ground itself in its own transcript).
        if chatRecallEnabled, !merged.isEmpty, let container = defaults.container {
            let recalled = (try? await retriever.search(SearchRequest(
                q: q, searchMode: "memories", rerank: false,
                threshold: defaults.threshold, limit: 3, container: "\(container)-chat"))) ?? []
            var added = 0
            let queryEcho = q.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            for h in recalled where seen.insert(dedupeKey(h)).inserted {
                // An echo of this very question (same turn asked before, or a
                // junk query's own transcript) is not knowledge — skip it.
                if queryEcho.count >= 12, h.memory.lowercased().contains(queryEcho) { continue }
                // Re-title so recalled turns cite legibly (not a raw transcript tag).
                let src = SourceLocator(docId: h.source.docId, path: h.source.path,
                                        title: Self.chatRecallTitle,
                                        charStart: h.source.charStart, charEnd: h.source.charEnd,
                                        updatedAt: h.source.updatedAt)
                // Secondary evidence: prior chat must never outrank the user's
                // actual documents, so its similarity is discounted.
                merged.append(Retrieved(memory: h.memory, similarity: h.similarity * 0.7, source: src))
                added += 1
            }
            if added > 0 { steps.append("Recalled \(added) fact\(added == 1 ? "" : "s") from earlier conversations") }
        }

        // Time-aware queries (#5): prefer sources from the named period.
        if let window = TimeWindow.parse(query: q) {
            merged = TimeWindow.filter(merged, to: window)
        }
        return Gathered(hits: merged, broadened: broadened, decomposed: decomposed, steps: steps)
    }

    /// Renderable events when the first search pass is empty and a retry is needed (A-108).
    static func gatherRetryEvents() -> [QueryEvent] {
        [.retrying("Initial search was empty — retrying with relaxed threshold…")]
    }

    /// Dedup key: docId when known, else path, else the text itself (agentic
    /// memory hits carry no docId).
    func dedupeKey(_ h: Retrieved) -> String {
        !h.source.docId.isEmpty ? "id:\(h.source.docId)"
            : (!h.source.path.isEmpty ? "path:\(h.source.path)" : "mem:\(h.memory)")
    }

    func search(_ q: String, mode: String) async throws -> [Retrieved] {
        try await retriever.search(SearchRequest(
            q: q, searchMode: mode, rerank: defaults.rerank,
            threshold: defaults.threshold, limit: defaults.limit, container: defaults.container))
    }
}

// // A-212:
extension QueryService {

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


// A-108:

    // MARK: - Query lifecycle events (M12)
    public static func lifecycleEvents(branch: LifecycleBranch) -> [QueryEvent] {
        switch branch {
        case .routeAmbiguity: return [.reasoning(["Ambiguous route — escalating to structured classification"])]
        case .emptyEvidence: return [.sources([]), .token("I don't have anything in your files about that.")]
        case .retry: return [.retrying("That wasn't grounded — reconsidering using only your files…")]
        }
    }
    public enum LifecycleBranch: String, Sendable { case routeAmbiguity, emptyEvidence, retry }

}

// // A-316:
extension QueryService {

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

}

// // A-264:
extension QueryService {

    // MARK: - Dreaming safety (M8)
    /// Synthesis must cite constituents and not duplicate existing memories.
    public static func dreamingSafeSynthesis(_ candidate: String, existing: [MemoryEntry],
                                              constituents: [String]) -> Bool {
        let live = existing.filter { $0.isLatest && !$0.isForgotten }.map(\.memory)
        guard !live.contains(candidate) else { return false }
        return constituents.allSatisfy { c in live.contains { $0.contains(c) || c.contains($0) } }
    }


// A-172:
public static func indexingTerminalState(path: String) -> TerminalState { .indexing(path: path) }
public static func ingestionSelfHealSafe(orphanIds: [String]) -> [String] { orphanIds.filter { !$0.isEmpty } }
}
