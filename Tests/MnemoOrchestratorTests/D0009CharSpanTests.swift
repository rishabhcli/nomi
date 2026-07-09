import XCTest
@testable import MnemoOrchestrator

/// D-0009: CharSpan memory supersession race conditions (seed 637aeadc46dd).
final class D0009CharSpanTests: XCTestCase {
    private let seed = "637aeadc46dd"

    func testPrefersLongestMatchWhenSupersededVersionsOverlap() {
        let doc = "version one alpha beta gamma version two alpha beta gamma delta"
        let range = CharSpan.resolve(chunk: "alpha beta gamma", in: doc)
        XCTAssertNotNil(range)
        let text = doc.substring(charRange: range!)
        XCTAssertEqual(text, "alpha beta gamma")
    }

    func testSingleTokenDoesNotResolve() {
        XCTAssertNil(CharSpan.resolve(chunk: "alpha", in: "alpha beta gamma"))
    }

    func testSupersessionKeyIncludesVersion() {
        let key = CharSpan.supersessionKey(docId: "d1", version: 2, range: 5..<10)
        XCTAssertEqual(key, "d1|v2|5-10")
        XCTAssertNotEqual(key, CharSpan.supersessionKey(docId: "d1", version: 1, range: 5..<10))
    }

    func testProperty_fuzzDeterministicResolution() {
        var rng = Phase2RNG(seed: seed)
        let words = ["alpha", "beta", "gamma", "delta", "epsilon"]
        let doc = words.joined(separator: " ")
        for _ in 0..<20 {
            let len = 2 + rng.nextInt(upperBound: 3)
            let start = rng.nextInt(upperBound: max(1, words.count - len))
            let chunk = words[start..<(start + len)].joined(separator: " ")
            let span = CharSpan.resolve(chunk: chunk, in: doc)
            XCTAssertNotNil(span, "multi-word chunk should resolve: \(chunk)")
            XCTAssertEqual(doc.substring(charRange: span!), chunk)
        }
    }
}
