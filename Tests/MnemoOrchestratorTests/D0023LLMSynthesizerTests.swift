import XCTest
@testable import MnemoOrchestrator

/// D-0023: LLMSynthesizer char-span fuzzing (seed 5ad937f8aed4).
final class D0023LLMSynthesizerTests: XCTestCase {
    private let seed = "5ad937f8aed4"

    func testCharSpanFuzzDeterministic() {
        var rng = Phase2RNG(seed: seed)
        for _ in 0..<10 {
            let len = 3 + rng.nextInt(upperBound: 40)
            var s = ""
            for _ in 0..<len { s += String(UnicodeScalar(97 + rng.nextInt(upperBound: 26))!) }
            XCTAssertTrue(LLMSynthesizer.charSpanFuzzSafe(s))
        }
    }
}
