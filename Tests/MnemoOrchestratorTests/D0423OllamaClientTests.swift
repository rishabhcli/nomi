import XCTest
@testable import MnemoOrchestrator

/// D-0423: OllamaClient char-span fuzzing (seed beae5eb84391).
final class D0423OllamaClientTests: XCTestCase {
    private let seed = "beae5eb84391"

    func testHighlightEmptyQuery() {
        XCTAssertTrue(Highlight.ranges(query: "the a", in: "hello world").isEmpty)
    }

    func testCharSpanBoundsSafe() {
        let text = "hello world"
        let ranges = Highlight.ranges(query: "hello world", in: text)
        for r in ranges {
            XCTAssertGreaterThanOrEqual(r.lowerBound, 0)
            XCTAssertLessThanOrEqual(r.upperBound, text.count)
        }
    }

    func testProperty_highlightDeterministic() {
        var rng = Phase2RNG(seed: seed)
        let words = ["hello", "world", "bazel", "rust"]
        for _ in 0..<6 {
            let q = words[rng.nextInt(upperBound: words.count)]
            let snippet = "prefix \(q) suffix"
            let a = Highlight.ranges(query: q, in: snippet)
            let b = Highlight.ranges(query: q, in: snippet)
            XCTAssertEqual(a, b)
        }
    }
}
