import XCTest
@testable import MnemoOrchestrator

/// D-0943: char-span fuzzing for Profile (seed 121c8f3da67b).
final class D0943ProfileTests: XCTestCase {
    private let seed = "121c8f3da67b"
    func testCharSpanFuzz_rng() {
        let doc = "alpha beta gamma delta"
        XCTAssertTrue(Phase2Techniques.charSpanFuzzSafe(doc: doc, chunk: "beta gamma"))
        XCTAssertNotNil(CharSpan.resolve(chunk: "beta gamma", in: doc))
    }

}
