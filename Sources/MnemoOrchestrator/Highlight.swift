import Foundation

/// Character ranges of a query's significant terms within a snippet, for
/// highlighting the match (helpfulness #4). Case-insensitive, whole-word,
/// skips short/stopword terms.
public enum Highlight {
    private static let stop: Set<String> = ["the", "a", "an", "of", "to", "in", "on", "is",
                                            "are", "was", "and", "or", "my", "i", "you", "it",
                                            "for", "with", "what", "who", "how", "did", "do"]

    public static func terms(_ query: String) -> [String] {
        query.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { $0.count > 2 && !stop.contains($0) }
    }

    /// Ranges over the snippet's Character array (matching CharSpan offsets).
    public static func ranges(query: String, in snippet: String) -> [Range<Int>] {
        let terms = Set(terms(query))
        guard !terms.isEmpty else { return [] }
        let chars = Array(snippet)
        var ranges: [Range<Int>] = []
        var i = 0
        while i < chars.count {
            guard chars[i].isLetter || chars[i].isNumber else { i += 1; continue }
            var j = i
            while j < chars.count, chars[j].isLetter || chars[j].isNumber { j += 1 }
            let word = String(chars[i..<j]).lowercased()
            if terms.contains(word) { ranges.append(i..<j) }
            i = j
        }
        return ranges
    }
}
