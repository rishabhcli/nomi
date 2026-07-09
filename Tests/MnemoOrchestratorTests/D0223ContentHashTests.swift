import XCTest
@testable import MnemoOrchestrator

/// D-0223: ContentHash char-span fuzzing (seed bf499d01dab8).
final class D0223ContentHashTests: XCTestCase {
    private let seed = "bf499d01dab8"

    func testCharSpanFuzzDeterministic() {
        var rng = Phase2RNG(seed: seed)
        for _ in 0..<10 {
            let len = 3 + rng.nextInt(upperBound: 40)
            var s = ""
            for _ in 0..<len { s += String(UnicodeScalar(97 + rng.nextInt(upperBound: 26))!) }
            XCTAssertTrue(ContentHash.charSpanFuzzSafe(s))
        }
    }
}
