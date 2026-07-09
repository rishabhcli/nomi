import XCTest
@testable import MnemoOrchestrator

/// D-0183: QueryDecomposer char-span fuzzing (seed a5d20d3e83e3).
final class D0183QueryDecomposerTests: XCTestCase {
    private let seed = "a5d20d3e83e3"

    func testCharSpanFuzzDeterministic() {
        var rng = Phase2RNG(seed: seed)
        for _ in 0..<10 {
            let len = 3 + rng.nextInt(upperBound: 40)
            var s = ""
            for _ in 0..<len { s += String(UnicodeScalar(97 + rng.nextInt(upperBound: 26))!) }
            XCTAssertTrue(QueryDecomposer.charSpanFuzzSafe(s))
        }
    }
}
