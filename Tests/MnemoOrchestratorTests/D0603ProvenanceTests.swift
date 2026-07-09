import XCTest
@testable import MnemoOrchestrator

/// D-0603: char-span fuzzing for Provenance (seed 3c973247f202).
final class D0603ProvenanceTests: XCTestCase {
    private let seed = "3c973247f202"

    func testCharSpan_fuzzSafe() {
        var rng = Phase2RNG(seed: seed)
        let words = ["alpha", "beta", "gamma", "delta"]
        let doc = words.joined(separator: " ")
        for _ in 0..<12 {
            let len = 2 + rng.nextInt(upperBound: 2)
            let start = rng.nextInt(upperBound: max(1, words.count - len))
            let chunk = words[start..<(start + len)].joined(separator: " ")
            XCTAssertTrue(Phase2Techniques.charSpanFuzzSafe(doc: doc, chunk: chunk))
            XCTAssertTrue(Provenance.charSpanFuzzSafe(doc))
        }
    }

    func testCharSpan_supersessionKey() {
        let k = Provenance.supersessionKey(id: "doc", version: 2)
        XCTAssertFalse(k.isEmpty)
    }

    func testCharSpan_resolveMultiWord() {
        XCTAssertNotNil(CharSpan.resolve(chunk: "alpha beta", in: "alpha beta gamma"))
    }

    func testFromAnswer_unsupportedHasNoSource() {
        let sources = [SourceCard(docId: "d", path: "/a.md", title: "A", relevance: 0.9)]
        let verdicts = Provenance.fromAnswer("Hallucinated.", unsupported: [0], sources: sources)
        XCTAssertNil(verdicts[0].bestSource)
        XCTAssertFalse(verdicts[0].supported)
    }
}
