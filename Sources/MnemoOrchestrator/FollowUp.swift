import Foundation

/// Expressive next-question suggestions derived from the retrieved evidence
/// (#6). Heuristic and deterministic — proposes deepening/relating questions
/// around the source documents and salient terms, never the original query.
public enum FollowUpSuggester {
    public static func suggest(query: String, evidence: [Retrieved], max: Int = 3) -> [String] {
        guard !evidence.isEmpty else { return [] }
        let normalizedQuery = query.lowercased().trimmingCharacters(in: .whitespaces)
        var out: [String] = []
        var seen = Set<String>()

        func add(_ s: String) {
            let key = s.lowercased()
            guard key != normalizedQuery, seen.insert(key).inserted else { return }
            out.append(s)
        }

        // 1. Deepen on the top source's document.
        let titles = evidence.compactMap { $0.source.title.isEmpty ? nil : $0.source.title }
        if let top = titles.first, top != "Untitled" {
            add("What else is in “\(top)”?")
        }
        // 2. Relate two distinct sources if the answer spanned more than one.
        let distinctTitles = titles.filter { $0 != "Untitled" }.reduced()
        if distinctTitles.count >= 2 {
            add("How do “\(distinctTitles[0])” and “\(distinctTitles[1])” relate?")
        }
        // 3. Salient capitalized entity from the evidence text.
        if let entity = salientEntity(in: evidence) {
            add("Tell me more about \(entity).")
        }
        // 4. Fallback deepener.
        add("Why does that matter?")

        return Array(out.prefix(max))
    }

    /// A capitalized multi/single-word entity that isn't a sentence start.
    private static func salientEntity(in evidence: [Retrieved]) -> String? {
        let stop: Set<String> = ["The", "A", "An", "I", "My", "User", "It", "This", "That", "We", "You"]
        for hit in evidence {
            let words = hit.memory.split(whereSeparator: { $0 == " " }).map(String.init)
            for (i, w) in words.enumerated() where i > 0 {  // skip sentence-initial
                let clean = w.trimmingCharacters(in: CharacterSet(charactersIn: ".,;:!?\"'()"))
                if let first = clean.first, first.isUppercase, clean.count > 2, !stop.contains(clean) {
                    return clean
                }
            }
        }
        return nil
    }
}

private extension Array where Element == String {
    /// Order-preserving unique.
    func reduced() -> [String] {
        var seen = Set<String>()
        return filter { seen.insert($0).inserted }
    }
}
