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
                do {
                    let chunks = try await docSearcher.searchDocuments(sub, container: defaults.container, limit: chunkLimit)
                    var added = 0
                    for h in chunks where seen.insert(dedupeKey(h)).inserted { merged.append(h); added += 1 }
                    if added > 0, hits.isEmpty { steps.append("Used the engine's document search") }
                } catch {
                    if hits.isEmpty { throw error }
                    steps.append("Document search unavailable for this sub-question")
                }
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
                for h in broader where seen.insert(dedupeKey(h)).inserted { merged.append(h) }
                broadened = true
                steps.append("Broadened the search (weak coverage)")
            }
        }

        // Agentic multi-hop (#1): follow the thread across files.
        if intent == .multihop, let agentic {
            let result = try await agentic.run(q, scope: nil)
            var added = 0
            for h in result.evidence where seen.insert(dedupeKey(h)).inserted { merged.append(h); added += 1 }
            if !result.hops.isEmpty { steps.append("Followed the thread across files (\(result.hops.count) hops, +\(added) evidence)") }
        }

        // Cross-session recall (beats-Siri #6): pull relevant prior conversation
        // turns from the dedicated chat space so it remembers earlier sessions.
        // Supplementary only — recalled chat can never be the sole "evidence"
        // (a junk query would otherwise ground itself in its own transcript).
        if chatRecallEnabled, !merged.isEmpty, let container = defaults.container {
            let recalled = try await retriever.search(SearchRequest(
                q: q, searchMode: "memories", rerank: false,
                threshold: defaults.threshold, limit: 3, container: "\(container)-chat"))
            var added = 0
            let queryEcho = q.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            for h in recalled {
                // An echo of this very question (same turn asked before, or a
                // junk query's own transcript) is not knowledge — skip it.
                if !queryEcho.isEmpty, h.memory.lowercased().contains(queryEcho) { continue }
                guard seen.insert(dedupeKey(h)).inserted else { continue }
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
        if !h.source.docId.isEmpty {
            if let s = h.source.charStart, let e = h.source.charEnd {
                return "id:\(h.source.docId)@\(s)-\(e)"
            }
            return "id:\(h.source.docId)|\(h.memory.prefix(80))"
        }
        if !h.source.path.isEmpty { return "path:\(h.source.path)|\(h.memory.prefix(80))" }
        return "mem:\(h.memory)"
    }

    func search(_ q: String, mode: String) async throws -> [Retrieved] {
        try await retriever.search(SearchRequest(
            q: q, searchMode: mode, rerank: defaults.rerank,
            threshold: defaults.threshold, limit: defaults.limit, container: defaults.container))
    }
}
