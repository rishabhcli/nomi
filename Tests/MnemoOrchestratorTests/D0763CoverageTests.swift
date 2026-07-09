import XCTest
@testable import MnemoOrchestrator

/// D-0763: char-span fuzzing for Coverage (seed 414d9eec4825).
final class D0763CoverageTests: XCTestCase {
    private let seed = "414d9eec4825"
    func testCharSpanFuzz_rng() {
        let doc = "alpha beta gamma delta"
        XCTAssertTrue(Phase2Techniques.charSpanFuzzSafe(doc: doc, chunk: "beta gamma"))
        XCTAssertNotNil(CharSpan.resolve(chunk: "beta gamma", in: doc))
    }

}
