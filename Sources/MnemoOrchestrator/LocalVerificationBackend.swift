import Foundation

/// On-device verification signals (M5), both loopback:
/// - similarity: token-overlap (Jaccard) as a cheap, deterministic floor —
///   no network, no model. Used to gate the (more expensive) entailment call.
/// - entailment: a low-effort yes/no from the local model.
public struct LocalVerificationBackend: VerificationBackend {
    let generator: Generating

    public init(generator: Generating) {
        self.generator = generator
    }

    static func tokens(_ s: String) -> Set<String> {
        Set(s.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { $0.count > 2 })   // drop stopword-ish short tokens
    }

    /// Overlap coefficient (intersection / smaller set) over the *claim* text —
    /// citation markup is stripped so we score the assertion, not its footnote.
    /// More forgiving than Jaccard for a short claim grounded in a longer chunk.
    public func similarity(_ a: String, _ b: String) async -> Double {
        let ta = Self.tokens(a), tb = Self.tokens(Verification.stripCitations(b))
        guard !ta.isEmpty, !tb.isEmpty else { return 0 }
        let inter = ta.intersection(tb).count
        return Double(inter) / Double(min(ta.count, tb.count))
    }

    public func entails(premise: String, hypothesis: String) async -> Bool {
        // Person-agnostic: I / you / the user denote the same person, so a
        // first-person memory grounds a second-person answer.
        let system = """
        You check whether a CLAIM is supported by EVIDENCE. Treat first/second/third \
        person as equivalent (I, you, and "the user" refer to the same person). \
        Answer with exactly one word: YES if the evidence supports the claim, otherwise NO.
        """
        let prompt = "EVIDENCE: \(premise)\n\nCLAIM: \(hypothesis)\n\nAnswer:"
        var raw = ""
        do {
            for try await tok in generator.stream(system: system, prompt: prompt) {
                raw += tok
            }
        } catch { return false }
        return Self.parseVerdict(raw)
    }

    /// The model may emit reasoning before its verdict; the last standalone
    /// YES/NO token wins. Word-boundary matching avoids "NO" inside NOT / KNOWN
    /// / CANNOT / NONE flipping a YES verdict.
    static func parseVerdict(_ raw: String) -> Bool {
        let tokens = raw.uppercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { $0 == "YES" || $0 == "NO" }
        guard let last = tokens.last else { return false }
        return last == "YES"
    }
}
