import XCTest
@testable import MnemoOrchestrator

/// D-0203: Highlight char-span fuzzing (seed 5d6a6d0e6239).
final class D0203HighlightTests: XCTestCase {
    private let seed = "5d6a6d0e6239"

    func testCharSpanFuzzDeterministic() {
        var rng = Phase2RNG(seed: seed)
        for _ in 0..<10 {
            let len = 3 + rng.nextInt(upperBound: 40)
            var s = ""
            for _ in 0..<len { s += String(UnicodeScalar(97 + rng.nextInt(upperBound: 26))!) }
            XCTAssertTrue(Highlight.charSpanFuzzSafe(s))
        }
    }
}
