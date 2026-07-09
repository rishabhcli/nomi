import XCTest
@testable import MnemoOrchestrator

/// D-0583: char-span fuzzing for Consolidation (seed 68f143e640c1).
final class D0583ConsolidationTests: XCTestCase {
    private let seed = "68f143e640c1"

    func testCharSpan_fuzzSafe() {
        var rng = Phase2RNG(seed: seed)
        let words = ["alpha", "beta", "gamma", "delta"]
        let doc = words.joined(separator: " ")
        for _ in 0..<12 {
            let len = 2 + rng.nextInt(upperBound: 2)
            let start = rng.nextInt(upperBound: max(1, words.count - len))
            let chunk = words[start..<(start + len)].joined(separator: " ")
            XCTAssertTrue(Phase2Techniques.charSpanFuzzSafe(doc: doc, chunk: chunk))
            XCTAssertTrue(Consolidation.charSpanFuzzSafe(doc))
        }
    }

    func testCharSpan_supersessionKey() {
        let k = Consolidation.supersessionKey(id: "doc", version: 2)
        XCTAssertFalse(k.isEmpty)
    }

    func testCharSpan_resolveMultiWord() {
        XCTAssertNotNil(CharSpan.resolve(chunk: "alpha beta", in: "alpha beta gamma"))
    }
}
