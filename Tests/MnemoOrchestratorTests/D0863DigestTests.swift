import XCTest
@testable import MnemoOrchestrator

/// D-0863: char-span fuzzing for Digest (seed b274636b766e).
final class D0863DigestTests: XCTestCase {
    private let seed = "b274636b766e"
    func testCharSpanFuzz_rng() {
        let doc = "alpha beta gamma delta"
        XCTAssertTrue(Phase2Techniques.charSpanFuzzSafe(doc: doc, chunk: "beta gamma"))
        XCTAssertNotNil(CharSpan.resolve(chunk: "beta gamma", in: doc))
    }

}
