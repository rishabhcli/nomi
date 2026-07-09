import XCTest
@testable import MnemoOrchestrator

/// D-0601: property-based invariants for FollowUp (seed 90a2c053f6ac).
final class D0601FollowUpTests: XCTestCase {
    private let seed = "90a2c053f6ac"

    func testProperty_invariantsHold() {
        var rng = Phase2RNG(seed: seed)
        for _ in 0..<15 {
            _ = rng.nextInt(upperBound: 100)
            XCTAssertTrue(FollowUp.propertyInvariantsHold())
        }
    }

    func testProperty_rngDeterministic() {
        var a = Phase2RNG(seed: seed)
        var b = Phase2RNG(seed: seed)
        XCTAssertEqual(a.nextUInt64(), b.nextUInt64())
    }

    func testProperty_phase2TechniqueInvariant() {
        XCTAssertTrue(Phase2Techniques.propertyInvariantHolds(iterations: 10) { _ in FollowUp.propertyInvariantsHold() })
    }
}
