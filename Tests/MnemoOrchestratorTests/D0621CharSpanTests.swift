import XCTest
@testable import MnemoOrchestrator

/// D-0621: property-based invariants for CharSpan (seed 9d75bcc4b603).
final class D0621CharSpanTests: XCTestCase {
    private let seed = "9d75bcc4b603"

    func testProperty_invariantsHold() {
        var rng = Phase2RNG(seed: seed)
        for _ in 0..<15 {
            _ = rng.nextInt(upperBound: 100)
            XCTAssertTrue(CharSpan.propertyInvariantsHold())
        }
    }

    func testProperty_rngDeterministic() {
        var a = Phase2RNG(seed: seed)
        var b = Phase2RNG(seed: seed)
        XCTAssertEqual(a.nextUInt64(), b.nextUInt64())
    }

    func testProperty_phase2TechniqueInvariant() {
        XCTAssertTrue(Phase2Techniques.propertyInvariantHolds(iterations: 10) { _ in CharSpan.propertyInvariantsHold() })
    }
}
