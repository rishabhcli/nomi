import Foundation

/// Shared M5 citation-integrity helpers — single implementation for all modules.
public enum GroundingCheck {
    public static func citationIntegritySupported(_ sentence: String, evidence: [Retrieved]) -> Bool {
        let claim = Verification.stripCitations(sentence).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !claim.isEmpty else { return true }
        let corpus = evidence.map { $0.memory.lowercased() }.joined(separator: " ")
        let tokens = claim.lowercased().split(whereSeparator: { !$0.isLetter && !$0.isNumber }).filter { $0.count > 3 }
        guard !tokens.isEmpty else { return true }
        return tokens.allSatisfy { corpus.contains($0) }
    }

    public static func unsupportedAnswerEvents() -> [QueryEvent] { [.state(.unsupportedAnswer)] }
}
