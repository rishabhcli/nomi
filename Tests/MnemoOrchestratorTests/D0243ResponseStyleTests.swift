import XCTest
@testable import MnemoOrchestrator

/// D-0243: ResponseStyle char-span fuzzing (seed a53864997dd6).
final class D0243ResponseStyleTests: XCTestCase {
    private let seed = "a53864997dd6"

    func testCharSpanFuzzDeterministic() {
        var rng = Phase2RNG(seed: seed)
        for _ in 0..<10 {
            let len = 3 + rng.nextInt(upperBound: 40)
            var s = ""
            for _ in 0..<len { s += String(UnicodeScalar(97 + rng.nextInt(upperBound: 26))!) }
            XCTAssertTrue(ResponseStyle.charSpanFuzzSafe(s))
        }
    }
}
