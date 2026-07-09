import XCTest
@testable import MnemoOrchestrator

/// D-0923: char-span fuzzing for EngineClient (seed 574db08908b8).
final class D0923EngineClientTests: XCTestCase {
    private let seed = "574db08908b8"
    func testCharSpanFuzz_rng() {
        let doc = "alpha beta gamma delta"
        XCTAssertTrue(Phase2Techniques.charSpanFuzzSafe(doc: doc, chunk: "beta gamma"))
        XCTAssertNotNil(CharSpan.resolve(chunk: "beta gamma", in: doc))
    }

}
