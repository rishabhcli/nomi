import XCTest
@testable import MnemoOrchestrator

/// D-0043: CommandParser char-span fuzzing (seed 4af6a7cee26c).
final class D0043CommandParserTests: XCTestCase {
    private let seed = "4af6a7cee26c"

    func testCharSpanFuzzDeterministic() {
        var rng = Phase2RNG(seed: seed)
        for _ in 0..<10 {
            let len = 3 + rng.nextInt(upperBound: 40)
            var s = ""
            for _ in 0..<len { s += String(UnicodeScalar(97 + rng.nextInt(upperBound: 26))!) }
            XCTAssertTrue(CommandParser.charSpanFuzzSafe(s))
        }
    }
}
