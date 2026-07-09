import XCTest
@testable import MnemoOrchestrator

/// D-0063: LLMHopPlanner char-span fuzzing (seed 04fdd7851326).
final class D0063LLMHopPlannerTests: XCTestCase {
    private let seed = "04fdd7851326"

    func testCharSpanFuzzDeterministic() {
        var rng = Phase2RNG(seed: seed)
        for _ in 0..<10 {
            let len = 3 + rng.nextInt(upperBound: 40)
            var s = ""
            for _ in 0..<len { s += String(UnicodeScalar(97 + rng.nextInt(upperBound: 26))!) }
            XCTAssertTrue(LLMHopPlanner.charSpanFuzzSafe(s))
        }
    }
}
