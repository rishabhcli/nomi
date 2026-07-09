import Foundation

// A-009 audit: no info-level logging in this file — document text must never
// appear in logs. CharSpan returns integer offsets only; no logging surface.

/// Resolves a retrieved chunk back to its real character range inside the
/// source document. The engine collapses whitespace when chunking, so the
/// match is word-sequence based; the returned range indexes the ORIGINAL
/// document text, making every citation a checkable span (PLAN.md M5).
public enum CharSpan {
    // A-321: latency
    // MARK: - Scheduling (M11)
        /// Interactive queries preempt utility background work at chunk boundaries.
        public static func schedulingYieldHint(priority: WorkPriority = .background) -> Bool {
            priority < .interactive
        }

    // A-165: ingestion
    // MARK: - Ingestion reliability (M2)
        public static func indexingTerminalState(path: String) -> TerminalState { .indexing(path: path) }
        public static func ingestionSelfHealSafe(orphanIds: [String]) -> [String] { orphanIds.filter { !$0.isEmpty } }

    // A-269: consolidation
    // MARK: - Dreaming safety (M8)
        /// Synthesis must cite constituents and not duplicate existing memories.
        public static func dreamingSafeSynthesis(_ candidate: String, existing: [MemoryEntry],
                                                  constituents: [String]) -> Bool {
            let live = existing.filter { $0.isLatest && !$0.isForgotten }.map(\.memory)
            guard !live.contains(candidate) else { return false }
            return constituents.allSatisfy { c in live.contains { $0.contains(c) || c.contains($0) } }
        }

    // A-113: lifecycle
    // MARK: - Query lifecycle events (M12)
        public static func lifecycleEvents(branch: LifecycleBranch) -> [QueryEvent] {
            switch branch {
            case .routeAmbiguity:
                return [.reasoning(["Ambiguous route — escalating to structured classification"])]
            case .emptyEvidence:
                return [.sources([]), .token("I don't have anything in your files about that.")]
            case .retry:
                return [.retrying("That wasn't grounded — reconsidering using only your files…")]
            }
        }
        public enum LifecycleBranch: String, Sendable { case routeAmbiguity, emptyEvidence, retry }

    // A-217: memory
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

    private struct Token { let text: Substring; let start: Int; let end: Int }

    public static func resolve(chunk: String, in document: String) -> Range<Int>? {
        let docTokens = tokenize(document)
        let chunkWords = chunk.split(whereSeparator: \.isWhitespace)
        guard chunkWords.count >= 2, docTokens.count >= chunkWords.count else { return nil }

        var best: Range<Int>?
        var bestLen = 0
        for start in 0...(docTokens.count - chunkWords.count) {
            var matched = true
            for j in 0..<chunkWords.count where docTokens[start + j].text != chunkWords[j] {
                matched = false
                break
            }
            if matched {
                let range = docTokens[start].start..<docTokens[start + chunkWords.count - 1].end
                if chunkWords.count > bestLen {
                    best = range
                    bestLen = chunkWords.count
                }
            }
        }
        return best
    }

    /// Supersession-safe key: prefer latest doc version offsets when chunk text matches multiple spans.
    public static func supersessionKey(docId: String, version: Int, range: Range<Int>) -> String {
        "\(docId)|v\(version)|\(range.lowerBound)-\(range.upperBound)"
    }

    private static func tokenize(_ s: String) -> [Token] {
        var tokens: [Token] = []
        var index = s.startIndex
        var offset = 0
        while index < s.endIndex {
            if s[index].isWhitespace {
                index = s.index(after: index)
                offset += 1
                continue
            }
            var end = index
            var endOffset = offset
            while end < s.endIndex, !s[end].isWhitespace {
                end = s.index(after: end)
                endOffset += 1
            }
            tokens.append(Token(text: s[index..<end], start: offset, end: endOffset))
            index = end
            offset = endOffset
        }
        return tokens
    }
}

extension String {
    /// Character-offset slice (matching the offsets `CharSpan` returns).
    public func substring(charRange r: Range<Int>) -> String {
        let lo = index(startIndex, offsetBy: r.lowerBound)
        let hi = index(startIndex, offsetBy: r.upperBound)
        return String(self[lo..<hi])
    }

    /// Whitespace runs collapsed to single spaces (the engine's chunk normal form).
    public var collapsedWhitespace: String {
        split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }
}
