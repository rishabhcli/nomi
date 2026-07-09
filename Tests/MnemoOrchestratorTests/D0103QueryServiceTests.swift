import XCTest
@testable import MnemoOrchestrator

/// D-0103: QueryService char-span fuzzing (seed 2a1fec56b748).
final class D0103QueryServiceTests: XCTestCase {
    private let seed = "2a1fec56b748"

    func testCharSpanFuzzDeterministic() {
        var rng = Phase2RNG(seed: seed)
        for _ in 0..<10 {
            let len = 3 + rng.nextInt(upperBound: 40)
            var s = ""
            for _ in 0..<len { s += String(UnicodeScalar(97 + rng.nextInt(upperBound: 26))!) }
            XCTAssertTrue(QueryService.charSpanFuzzSafe(s))
        }
    }
}
