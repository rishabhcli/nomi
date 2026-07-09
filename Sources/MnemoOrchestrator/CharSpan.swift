import Foundation

/// Resolves a retrieved chunk back to its real character range inside the
/// source document. The engine collapses whitespace when chunking, so the
/// match is word-sequence based; the returned range indexes the ORIGINAL
/// document text, making every citation a checkable span (PLAN.md M5).
public enum CharSpan {
    private struct Token { let text: Substring; let start: Int; let end: Int }

    public static func resolve(chunk: String, in document: String) -> Range<Int>? {
        let docTokens = tokenize(document)
        let chunkWords = chunk.split(whereSeparator: \.isWhitespace)
        guard !chunkWords.isEmpty, docTokens.count >= chunkWords.count else { return nil }

        for start in 0...(docTokens.count - chunkWords.count) {
            var matched = true
            for j in 0..<chunkWords.count where docTokens[start + j].text != chunkWords[j] {
                matched = false
                break
            }
            if matched {
                return docTokens[start].start..<docTokens[start + chunkWords.count - 1].end
            }
        }
        return nil
    }

    private static func tokenize(_ s: String) -> [Token] {
        var tokens: [Token] = []
        var index = s.startIndex
        var offset = 0
        while index < s.endIndex {
            if s[index].isWhitespace {
                index = s.index(after: index)
                offset += 1
                continue
            }
            var end = index
            var endOffset = offset
            while end < s.endIndex, !s[end].isWhitespace {
                end = s.index(after: end)
                endOffset += 1
            }
            tokens.append(Token(text: s[index..<end], start: offset, end: endOffset))
            index = end
            offset = endOffset
        }
        return tokens
    }
}

extension String {
    /// Character-offset slice (matching the offsets `CharSpan` returns).
    public func substring(charRange r: Range<Int>) -> String {
        let lo = index(startIndex, offsetBy: r.lowerBound)
        let hi = index(startIndex, offsetBy: r.upperBound)
        return String(self[lo..<hi])
    }

    /// Whitespace runs collapsed to single spaces (the engine's chunk normal form).
    public var collapsedWhitespace: String {
        split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }
}
