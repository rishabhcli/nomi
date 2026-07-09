import XCTest
@testable import MnemoOrchestrator

/// D-0163: AgenticGrep char-span fuzzing (seed 932cc64e8284).
final class D0163AgenticGrepTests: XCTestCase {
    private let seed = "932cc64e8284"

    func testCharSpanFuzzDeterministic() {
        var rng = Phase2RNG(seed: seed)
        for _ in 0..<10 {
            let len = 3 + rng.nextInt(upperBound: 40)
            var s = ""
            for _ in 0..<len { s += String(UnicodeScalar(97 + rng.nextInt(upperBound: 26))!) }
            XCTAssertTrue(AgenticGrep.charSpanFuzzSafe(s))
        }
    }
}
