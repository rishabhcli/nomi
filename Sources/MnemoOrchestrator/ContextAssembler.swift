import Foundation

/// The assembled generation context: a persistent profile preamble plus
/// relevance-trimmed evidence, bounded by a token budget (PLAN.md M4).
public struct AssembledContext: Equatable, Sendable {
    public let preamble: String
    public let evidence: [Retrieved]
    public let tokenBudget: Int
    public var estimatedTokens: Int {
        TokenEstimate.of(preamble) + evidence.reduce(0) { $0 + TokenEstimate.of($1.memory) }
    }
}

/// Cheap, deterministic token estimate (~4 chars/token) — enough to bound
/// context without a tokenizer dependency.
public enum TokenEstimate {
    public static func of(_ s: String) -> Int { max(1, (s.count + 3) / 4) }
}

/// Builds context: profile as a system preamble, then reranked evidence,
/// trimming lowest-relevance first and capping the preamble so evidence
/// always gets a share of the budget.
public struct ContextAssembler: Sendable {
    let tokenBudget: Int
    let preambleFraction: Double   // max share of the budget the preamble may take

    public init(tokenBudget: Int, preambleFraction: Double = 0.5) {
        self.tokenBudget = tokenBudget
        self.preambleFraction = preambleFraction
    }

    public func assemble(intent: Intent, question: String,
                         profile: Profile, evidence: [Retrieved]) -> AssembledContext {
        let preamble = buildPreamble(profile, cap: Int(Double(tokenBudget) * preambleFraction))
        let remaining = max(0, tokenBudget - TokenEstimate.of(preamble))

        // Highest similarity first; keep while it fits.
        let ranked = evidence.sorted { $0.similarity > $1.similarity }
        var kept: [Retrieved] = []
        var used = 0
        for hit in ranked {
            let cost = TokenEstimate.of(hit.memory)
            if used + cost > remaining { continue }   // skip; a smaller later hit may still fit
            kept.append(hit)
            used += cost
        }
        return AssembledContext(preamble: preamble, evidence: kept, tokenBudget: tokenBudget)
    }

    private func buildPreamble(_ profile: Profile, cap: Int) -> String {
        var lines = ["You are Mnemo. Here is what you already know about the user:"]
        var used = TokenEstimate.of(lines[0])
        func add(_ label: String, _ facts: [String]) {
            for fact in facts {
                let line = "- [\(label)] \(fact)"
                let cost = TokenEstimate.of(line)
                if used + cost > cap { return }
                lines.append(line)
                used += cost
            }
        }
        add("stable", profile.statics)
        add("current", profile.dynamics)
        if lines.count == 1 { lines.append("- (no profile facts yet)") }
        return lines.joined(separator: "\n")
    }
}
