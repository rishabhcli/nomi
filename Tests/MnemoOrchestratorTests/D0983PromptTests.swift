import XCTest
@testable import MnemoOrchestrator

/// D-0983: char-span fuzzing for Prompt (seed dc25e8bc0daa).
final class D0983PromptTests: XCTestCase {
    private let seed = "dc25e8bc0daa"
    func testCharSpanFuzz_rng() {
        let doc = "alpha beta gamma delta"
        XCTAssertTrue(Phase2Techniques.charSpanFuzzSafe(doc: doc, chunk: "beta gamma"))
        XCTAssertNotNil(CharSpan.resolve(chunk: "beta gamma", in: doc))
    }

}
