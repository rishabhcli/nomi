import XCTest
@testable import MnemoOrchestrator

/// D-0523: char-span fuzzing for ContextAssembler (seed 1c5aaf2121dc).
final class D0523ContextAssemblerTests: XCTestCase {
    private let seed = "1c5aaf2121dc"

    func testCharSpan_fuzzSafe() {
        var rng = Phase2RNG(seed: seed)
        let words = ["alpha", "beta", "gamma", "delta"]
        let doc = words.joined(separator: " ")
        for _ in 0..<12 {
            let len = 2 + rng.nextInt(upperBound: 2)
            let start = rng.nextInt(upperBound: max(1, words.count - len))
            let chunk = words[start..<(start + len)].joined(separator: " ")
            XCTAssertTrue(Phase2Techniques.charSpanFuzzSafe(doc: doc, chunk: chunk))
            XCTAssertTrue(ContextAssembler.charSpanFuzzSafe(doc))
        }
    }

    func testCharSpan_supersessionKey() {
        let k = ContextAssembler.supersessionKey(id: "doc", version: 2)
        XCTAssertFalse(k.isEmpty)
    }

    func testCharSpan_resolveMultiWord() {
        XCTAssertNotNil(CharSpan.resolve(chunk: "alpha beta", in: "alpha beta gamma"))
    }
}
