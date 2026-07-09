import XCTest
@testable import MnemoOrchestrator

/// D-0123: ConflictDetector char-span fuzzing (seed 9e14a3ee075c).
final class D0123ConflictDetectorTests: XCTestCase {
    private let seed = "9e14a3ee075c"

    func testCharSpanFuzzDeterministic() {
        var rng = Phase2RNG(seed: seed)
        for _ in 0..<10 {
            let len = 3 + rng.nextInt(upperBound: 40)
            var s = ""
            for _ in 0..<len { s += String(UnicodeScalar(97 + rng.nextInt(upperBound: 26))!) }
            XCTAssertTrue(ConflictDetector.charSpanFuzzSafe(s))
        }
    }
}
