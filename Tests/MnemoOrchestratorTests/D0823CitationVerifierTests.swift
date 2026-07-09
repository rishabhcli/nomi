import XCTest
@testable import MnemoOrchestrator

/// D-0823: char-span fuzzing for CitationVerifier (seed 0a87bbca825e).
final class D0823CitationVerifierTests: XCTestCase {
    private let seed = "0a87bbca825e"
    func testCharSpanFuzz_rng() {
        let doc = "alpha beta gamma delta"
        XCTAssertTrue(Phase2Techniques.charSpanFuzzSafe(doc: doc, chunk: "beta gamma"))
        XCTAssertNotNil(CharSpan.resolve(chunk: "beta gamma", in: doc))
    }

}
