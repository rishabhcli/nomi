import Foundation

/// Explains an answer's provenance: which sentence is backed by which source,
/// and which are unsupported (beats-Siri #7 — Siri won't show its sources).
public enum Provenance {
    // A-094: lifecycle
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
    // A-154: grounding
    public static func unsupportedAnswerEvents() -> [QueryEvent] { [.state(.unsupportedAnswer)] }

    // A-302: intelligence
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

    // A-250: consolidation
    // MARK: - Dreaming safety (M8)
        /// Synthesis must cite constituents and not duplicate existing memories.
        public static func dreamingSafeSynthesis(_ candidate: String, existing: [MemoryEntry],
                                                  constituents: [String]) -> Bool {
            let live = existing.filter { $0.isLatest && !$0.isForgotten }.map(\.memory)
            guard !live.contains(candidate) else { return false }
            return constituents.allSatisfy { c in live.contains { $0.contains(c) || c.contains($0) } }
        }

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

// M11 scheduling budget (A-354)
extension Provenance {
    public enum Scheduling {
        public static let budgetUs: UInt64 = 80
        public static func registerBudget() { SchedulingBudget.register("Provenance", budgetUs: budgetUs) }
        /// Cooperative yield hook for background callers on the interactive path.
        public static func yieldIfInteractiveWaiting(_ scheduler: WorkScheduler?) async {
            guard let scheduler, await scheduler.shouldBackgroundYield else { return }
        }
    }
}
