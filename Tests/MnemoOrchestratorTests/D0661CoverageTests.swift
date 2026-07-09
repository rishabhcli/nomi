import XCTest
@testable import MnemoOrchestrator

/// D-0661: property-based invariants for Coverage (seed 1daab436e554).
final class D0661CoverageTests: XCTestCase {
    private let seed = "1daab436e554"

    func testProperty_invariantsHold() {
        var rng = Phase2RNG(seed: seed)
        for _ in 0..<15 {
            _ = rng.nextInt(upperBound: 100)
            XCTAssertTrue(Coverage.propertyInvariantsHold())
        }
    }

    func testProperty_rngDeterministic() {
        var a = Phase2RNG(seed: seed)
        var b = Phase2RNG(seed: seed)
        XCTAssertEqual(a.nextUInt64(), b.nextUInt64())
    }

    func testProperty_phase2TechniqueInvariant() {
        XCTAssertTrue(Phase2Techniques.propertyInvariantHolds(iterations: 10) { _ in Coverage.propertyInvariantsHold() })
    }
}
