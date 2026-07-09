import Foundation

/// Pulls salient entities (capitalized names, acronyms) from text so the UI can
/// offer pivot-to-explore chips (intelligence #8).
public enum EntityExtractor {
    private static let stop: Set<String> = ["The", "A", "An", "I", "My", "User", "It", "This",
                                            "That", "We", "You", "In", "On", "Of", "And", "Or",
                                            "But", "Your", "Their", "His", "Her", "Its"]

    public static func entities(in text: String, max: Int = 5) -> [String] {
        var out: [String] = []
        var seen = Set<String>()
        // Strip inline citations ([…], 【…】) and markdown emphasis so neither
        // masks nor masquerades as an entity.
        let clean = Verification.stripCitations(text)
            .replacingOccurrences(of: "**", with: "")
            .replacingOccurrences(of: "*", with: "").replacingOccurrences(of: "`", with: "")
            .replacingOccurrences(of: "_", with: "")
        // Split into sentences so we can ignore the sentence-initial capital.
        for sentence in clean.split(whereSeparator: { ".!?\n".contains($0) }) {
            let words = sentence.split(separator: " ").map(String.init)
            for (i, raw) in words.enumerated() {
                let w = raw.trimmingCharacters(in: CharacterSet(charactersIn: ",;:\"'()[]【】"))
                guard w.count > 2, let first = w.first, first.isUppercase, !stop.contains(w) else { continue }
                // Skip the first word of a sentence unless it's ALL-CAPS (an acronym).
                if i == 0 && w != w.uppercased() { continue }
                if seen.insert(w).inserted { out.append(w) }
                if out.count >= max { return out }
            }
        }
        return out
    }
}
