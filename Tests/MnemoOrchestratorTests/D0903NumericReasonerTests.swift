import XCTest
@testable import MnemoOrchestrator

/// D-0903: char-span fuzzing for NumericReasoner (seed 5a4ea3abc044).
final class D0903NumericReasonerTests: XCTestCase {
    private let seed = "5a4ea3abc044"
    func testCharSpanFuzz_rng() {
        let doc = "alpha beta gamma delta"
        XCTAssertTrue(Phase2Techniques.charSpanFuzzSafe(doc: doc, chunk: "beta gamma"))
        XCTAssertNotNil(CharSpan.resolve(chunk: "beta gamma", in: doc))
    }

}
