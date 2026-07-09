import Foundation

/// Extracts the sentence containing a cited char range, for a highlighted
/// provenance preview (#8) — the exact text the citation points at, not just
/// the file name.
public enum SpanPreview {
    public static func sentence(around range: Range<Int>, in document: String) -> String {
        let chars = Array(document)
        guard !chars.isEmpty else { return "" }
        let lo = max(0, min(range.lowerBound, chars.count - 1))
        let hi = max(lo, min(range.upperBound, chars.count))

        // Walk left/right to sentence terminators.
        var start = lo
        while start > 0 {
            let c = chars[start - 1]
            if c == "." || c == "!" || c == "?" || c == "\n" { break }
            start -= 1
        }
        var end = hi
        while end < chars.count {
            let c = chars[end]
            end += 1
            if c == "." || c == "!" || c == "?" || c == "\n" { break }
        }
        return String(chars[start..<end]).trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
