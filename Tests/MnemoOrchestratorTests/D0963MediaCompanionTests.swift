import XCTest
@testable import MnemoOrchestrator

/// D-0963: char-span fuzzing for MediaCompanion (seed b3ae5d6255a2).
final class D0963MediaCompanionTests: XCTestCase {
    private let seed = "b3ae5d6255a2"
    func testCharSpanFuzz_rng() {
        let doc = "alpha beta gamma delta"
        XCTAssertTrue(Phase2Techniques.charSpanFuzzSafe(doc: doc, chunk: "beta gamma"))
        XCTAssertNotNil(CharSpan.resolve(chunk: "beta gamma", in: doc))
    }

}
