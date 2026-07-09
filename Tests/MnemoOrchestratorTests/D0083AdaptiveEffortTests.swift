import XCTest
@testable import MnemoOrchestrator

/// D-0083: AdaptiveEffort char-span fuzzing (seed 88260ee984c9).
final class D0083AdaptiveEffortTests: XCTestCase {
    private let seed = "88260ee984c9"

    func testCharSpanFuzzDeterministic() {
        var rng = Phase2RNG(seed: seed)
        for _ in 0..<10 {
            let len = 3 + rng.nextInt(upperBound: 40)
            var s = ""
            for _ in 0..<len { s += String(UnicodeScalar(97 + rng.nextInt(upperBound: 26))!) }
            XCTAssertTrue(AdaptiveEffort.charSpanFuzzSafe(s))
        }
    }
}
