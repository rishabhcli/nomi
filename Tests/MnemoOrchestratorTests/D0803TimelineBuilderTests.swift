import XCTest
@testable import MnemoOrchestrator

/// D-0803: char-span fuzzing for TimelineBuilder (seed 09afa8fbbe3d).
final class D0803TimelineBuilderTests: XCTestCase {
    private let seed = "09afa8fbbe3d"
    func testCharSpanFuzz_rng() {
        let doc = "alpha beta gamma delta"
        XCTAssertTrue(Phase2Techniques.charSpanFuzzSafe(doc: doc, chunk: "beta gamma"))
        XCTAssertNotNil(CharSpan.resolve(chunk: "beta gamma", in: doc))
    }

}
