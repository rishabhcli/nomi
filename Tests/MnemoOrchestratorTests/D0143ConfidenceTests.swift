import XCTest
@testable import MnemoOrchestrator

/// D-0143: Confidence char-span fuzzing (seed 8a84334c6db7).
final class D0143ConfidenceTests: XCTestCase {
    private let seed = "8a84334c6db7"

    func testCharSpanFuzzDeterministic() {
        var rng = Phase2RNG(seed: seed)
        for _ in 0..<10 {
            let len = 3 + rng.nextInt(upperBound: 40)
            var s = ""
            for _ in 0..<len { s += String(UnicodeScalar(97 + rng.nextInt(upperBound: 26))!) }
            XCTAssertTrue(Confidence.charSpanFuzzSafe(s))
        }
    }
}
