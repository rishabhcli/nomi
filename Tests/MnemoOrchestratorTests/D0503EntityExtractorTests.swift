import XCTest
@testable import MnemoOrchestrator

/// D-0503: char-span fuzzing for EntityExtractor (seed 2f0508eb8dfb).
final class D0503EntityExtractorTests: XCTestCase {
    private let seed = "2f0508eb8dfb"

    func testCharSpan_fuzzSafe() {
        var rng = Phase2RNG(seed: seed)
        let words = ["alpha", "beta", "gamma", "delta"]
        let doc = words.joined(separator: " ")
        for _ in 0..<12 {
            let len = 2 + rng.nextInt(upperBound: 2)
            let start = rng.nextInt(upperBound: max(1, words.count - len))
            let chunk = words[start..<(start + len)].joined(separator: " ")
            XCTAssertTrue(Phase2Techniques.charSpanFuzzSafe(doc: doc, chunk: chunk))
            XCTAssertTrue(EntityExtractor.charSpanFuzzSafe(doc))
        }
    }

    func testCharSpan_supersessionKey() {
        let k = EntityExtractor.supersessionKey(id: "doc", version: 2)
        XCTAssertFalse(k.isEmpty)
    }

    func testCharSpan_resolveMultiWord() {
        XCTAssertNotNil(CharSpan.resolve(chunk: "alpha beta", in: "alpha beta gamma"))
    }

    func testEntities_extractsMidSentence() {
        let ents = EntityExtractor.entities(in: "Notes mention Rust often.")
        XCTAssertTrue(ents.contains("Rust"))
    }
}
