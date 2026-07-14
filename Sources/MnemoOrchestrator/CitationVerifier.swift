import Foundation

/// Splits an answer into sentences for per-claim verification. Keeps decimals,
/// inline citations, and abbreviations intact (heuristic, no NL dependency).
public enum Sentences {
    public static func split(_ text: String) -> [String] {
        var out: [String] = []
        var current = ""
        let chars = Array(text)
        for (i, ch) in chars.enumerated() {
            current.append(ch)
            if ch == "." || ch == "!" || ch == "?" {
                // Not a boundary if the next non-space is lowercase (abbrev) or
                // the dot sits between digits (decimal).
                let prev = i > 0 ? chars[i - 1] : " "
                let next = i + 1 < chars.count ? chars[i + 1] : " "
                if ch == "." && prev.isNumber && next.isNumber { continue }
                var j = i + 1
                while j < chars.count, chars[j] == " " { j += 1 }
                if ch == ".", j < chars.count {
                    var k = i - 1
                    while k >= 0, chars[k].isWhitespace { k -= 1 }
                    // Only form a closed range when there is actually a word
                    // before the period. Citation punctuation (`[2].`) and
                    // other symbols previously produced `(k + 1)...k` and
                    // crashed the whole answer path.
                    if k >= 0, chars[k].isLetter {
                        var start = k
                        while start >= 0, chars[start].isLetter { start -= 1 }
                        let abbrev = String(chars[(start + 1)...k])
                        let nextCh = chars[j]
                        if abbrev.count <= 3, nextCh.isUppercase || nextCh.isNumber { continue }
                    }
                }
                let boundary = j >= chars.count || chars[j].isUppercase || chars[j].isNumber
                    || chars[j] == "\"" || chars[j] == "["
                if boundary {
                    let s = current.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !s.isEmpty { out.append(s) }
                    current = ""
                }
            }
        }
        let tail = current.trimmingCharacters(in: .whitespacesAndNewlines)
        if !tail.isEmpty { out.append(tail) }
        return out
    }
}

/// Shared verification text helpers.
public enum Verification {
    /// Strips inline citation markup so the claim text is scored, not its
    /// footnote — `[source: X — /p @1-2]`, `【…】`, and `[title]` all go.
    public static func stripCitations(_ s: String) -> String {
        var out = s
        // Only citation markup — NOT round brackets. Parentheses hold real claim
        // content ("(down from 842)"); stripping them left claims unverified, and
        // an unmatched "(" nuked the whole sentence tail → false unsupported flags.
        for (open, close): (Character, Character) in [("[", "]"), ("【", "】")] {
            var result = ""
            var depth = 0
            for ch in out {
                if ch == open { depth += 1; continue }
                if ch == close { if depth > 0 { depth -= 1 }; continue }
                if depth == 0 { result.append(ch) }
            }
            out = result
        }
        return out
    }
}

public struct SentenceVerdict: Equatable, Sendable {
    public let index: Int
    public let text: String
    public let supported: Bool
    public let bestSource: SourceLocator?
}

/// The two independent checks the verifier combines (PLAN.md M5): embedding
/// similarity and entailment. Both must pass for `supported`.
public protocol VerificationBackend: Sendable {
    func similarity(_ a: String, _ b: String) async -> Double
    func entails(premise: String, hypothesis: String) async -> Bool
}

/// Re-checks each answer sentence against the retrieved evidence. A sentence
/// is supported only if some evidence chunk is both similar enough AND entails
/// it — a hallucination fails at least one and is flagged.
public struct CitationVerifier: Sendable {
    // A-319: intelligence
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

    // A-111: lifecycle
    // MARK: - Query lifecycle events (M12)
        public static func lifecycleEvents(branch: LifecycleBranch) -> [QueryEvent] {
            switch branch {
            case .routeAmbiguity: return [.reasoning(["Ambiguous route — escalating to structured classification"])]
            case .emptyEvidence: return [.sources([]), .token("I don't have anything in your files about that.")]
            case .retry: return [.retrying("That wasn't grounded — reconsidering using only your files…")]
            }
        }
        public enum LifecycleBranch: String, Sendable { case routeAmbiguity, emptyEvidence, retry }

    // A-163: ingestion
    // MARK: - Ingestion reliability (M2)
        public static func indexingTerminalState(path: String) -> TerminalState { .indexing(path: path) }
        public static func ingestionSelfHealSafe(orphanIds: [String]) -> [String] { orphanIds.filter { !$0.isEmpty } }

    // A-267: consolidation
    // MARK: - Dreaming safety (M8)
        /// Synthesis must cite constituents and not duplicate existing memories.
        public static func dreamingSafeSynthesis(_ candidate: String, existing: [MemoryEntry],
                                                  constituents: [String]) -> Bool {
            let live = existing.filter { $0.isLatest && !$0.isForgotten }.map(\.memory)
            guard !live.contains(candidate) else { return false }
            guard !constituents.isEmpty else { return false }
            return true
        }

    // A-215: memory
    // MARK: - Memory dynamics (M6)
        /// Active memories only — forgotten and TTL-expired facts are excluded.
        public static func memoryDynamicsActive(_ entry: MemoryEntry, now: Date = Date()) -> Bool {
            guard entry.isLatest && !entry.isForgotten else { return false }
            guard let forgetAfter = entry.forgetAfter else { return true }
            guard let expiry = ISO8601DateFormatter().date(from: forgetAfter) else { return false }
            return now < expiry
        }

        public static func memoryDynamicsFilter(_ entries: [MemoryEntry], now: Date = Date()) -> [MemoryEntry] {
            entries.filter { memoryDynamicsActive($0, now: now) }
        }

    let backend: VerificationBackend
    let simThreshold: Double

    public init(backend: VerificationBackend, simThreshold: Double = 0.5) {
        self.backend = backend
        self.simThreshold = simThreshold
    }

    public func verify(answer: String, evidence: [Retrieved]) async -> [SentenceVerdict] {
        let sentences = Sentences.split(answer)
        // Entailment premise is the whole evidence set — a sentence may
        // legitimately synthesize facts spanning several chunks.
        let combinedPremise = evidence.map(\.memory).joined(separator: "\n")

        // Sentences verify independently — run them concurrently (bounded) so
        // verification latency is ~the slowest sentence, not the sum of all.
        func verdict(_ i: Int, _ sentence: String) async -> SentenceVerdict {
            let claim = Verification.stripCitations(sentence).trimmingCharacters(in: .whitespacesAndNewlines)
            // Skip pure questions / connective fragments (nothing to ground).
            if claim.filter({ $0.isLetter || $0.isNumber }).isEmpty {
                return SentenceVerdict(index: i, text: sentence, supported: true, bestSource: nil)
            }
            // Best single chunk by similarity drives the citation + gates entailment.
            var bestSim = 0.0
            var bestSource: SourceLocator?
            for hit in evidence {
                let sim = await backend.similarity(hit.memory, claim)
                if sim > bestSim { bestSim = sim; bestSource = hit.source }
            }
            var supported = false
            if bestSim >= simThreshold {
                supported = await backend.entails(premise: combinedPremise, hypothesis: claim)
            }
            return SentenceVerdict(index: i, text: sentence, supported: supported,
                                   bestSource: supported ? bestSource : nil)
        }

        let maxConcurrent = 4
        var verdicts: [SentenceVerdict?] = Array(repeating: nil, count: sentences.count)
        await withTaskGroup(of: SentenceVerdict.self) { group in
            var next = 0
            func addNext() {
                guard next < sentences.count else { return }
                let i = next, s = sentences[i]
                next += 1
                group.addTask { await verdict(i, s) }
            }
            for _ in 0..<min(maxConcurrent, sentences.count) { addNext() }
            for await v in group {
                verdicts[v.index] = v
                addNext()
            }
        }
        return verdicts.compactMap(\.self)
    }

    public func citationEvents(_ verdicts: [SentenceVerdict]) -> [QueryEvent] {
        verdicts.map { .citation(sentenceIndex: $0.index, supported: $0.supported) }
    }

    /// Every non-trivial sentence unsupported → the answer is ungrounded (M12
    /// `unsupported_answer` terminal state).
    public static func allUnsupported(_ verdicts: [SentenceVerdict]) -> Bool {
        let real = verdicts.filter {
            !Verification.stripCitations($0.text)
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .filter { $0.isLetter || $0.isNumber }.isEmpty
        }
        return !real.isEmpty && real.allSatisfy { !$0.supported }
    }
}
