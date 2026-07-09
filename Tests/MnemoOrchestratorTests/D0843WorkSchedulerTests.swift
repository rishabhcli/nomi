import XCTest
@testable import MnemoOrchestrator

/// D-0843: char-span fuzzing for WorkScheduler (seed acc9a06f88e6).
final class D0843WorkSchedulerTests: XCTestCase {
    private let seed = "acc9a06f88e6"
    func testCharSpanFuzz_rng() {
        let doc = "alpha beta gamma delta"
        XCTAssertTrue(Phase2Techniques.charSpanFuzzSafe(doc: doc, chunk: "beta gamma"))
        XCTAssertNotNil(CharSpan.resolve(chunk: "beta gamma", in: doc))
    }

}
