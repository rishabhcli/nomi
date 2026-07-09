import Foundation

/// Explains an answer's provenance: which sentence is backed by which source,
/// and which are unsupported (beats-Siri #7 — Siri won't show its sources).
public enum Provenance {
    public static func explain(_ verdicts: [SentenceVerdict]) -> String {
        guard !verdicts.isEmpty else { return "No answer to explain yet." }
        var lines = ["Here's why I said that:"]
        for v in verdicts where v.text.count >= 3 {
            if v.supported, let src = v.bestSource {
                lines.append("• “\(v.text)” — from \(src.title)")
            } else {
                lines.append("• ⚠ “\(v.text)” — unsupported by your files")
            }
        }
        return lines.joined(separator: "\n")
    }

    /// Reconstructs claim→source verdicts from a rendered answer: each
    /// sentence's `[n]` citation marker maps to the n-th source card, and the
    /// verifier's unsupported set marks failed claims.
    public static func fromAnswer(_ answer: String, unsupported: Set<Int>,
                                  sources: [SourceCard]) -> [SentenceVerdict] {
        Sentences.split(answer).enumerated().map { idx, sentence in
            var best: SourceLocator?
            if let range = sentence.range(of: #"\[(\d+)\]"#, options: .regularExpression),
               let n = Int(sentence[range].dropFirst().dropLast()), n >= 1, n <= sources.count {
                let card = sources[n - 1]
                best = SourceLocator(docId: card.docId, path: card.path, title: card.title)
            } else if let first = sources.first {
                best = SourceLocator(docId: first.docId, path: first.path, title: first.title)
            }
            return SentenceVerdict(index: idx, text: sentence,
                                   supported: !unsupported.contains(idx), bestSource: best)
        }
    }
}

/// Confidence introspection: "how sure are you?" answered honestly from the
/// measured grounding (beats-Siri #8 — Siri never calibrates or abstains).
public enum ConfidenceReport {
    public static func isMetaQuestion(_ query: String) -> Bool {
        let q = query.lowercased()
        return q.contains("how confident") || q.contains("how sure")
            || q.contains("are you sure") || q.contains("how certain")
    }
    public static func report(_ level: ConfidenceLevel, sourceCount: Int) -> String {
        let src = sourceCount == 1 ? "1 source" : "\(sourceCount) sources"
        switch level {
        case .high: return "Confident — that answer is grounded in \(src) from your files."
        case .medium: return "Moderately sure — it's based on \(src); worth checking the citations."
        case .low: return "Not confident — I couldn't firmly ground that in your files."
        }
    }
}
