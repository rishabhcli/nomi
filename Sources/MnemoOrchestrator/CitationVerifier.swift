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
            if claim.count < 3 { return SentenceVerdict(index: i, text: sentence, supported: true, bestSource: nil) }
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
        let real = verdicts.filter { $0.text.count >= 3 }
        return !real.isEmpty && real.allSatisfy { !$0.supported }
    }
}
