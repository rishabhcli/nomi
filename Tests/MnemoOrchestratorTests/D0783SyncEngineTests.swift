import XCTest
@testable import MnemoOrchestrator

/// D-0783: char-span fuzzing for SyncEngine (seed 97094db4b16f).
final class D0783SyncEngineTests: XCTestCase {
    private let seed = "97094db4b16f"
    func testCharSpanFuzz_rng() {
        let doc = "alpha beta gamma delta"
        XCTAssertTrue(Phase2Techniques.charSpanFuzzSafe(doc: doc, chunk: "beta gamma"))
        XCTAssertNotNil(CharSpan.resolve(chunk: "beta gamma", in: doc))
    }

}
