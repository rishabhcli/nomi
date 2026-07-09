import XCTest
@testable import MnemoOrchestrator

/// D-0701: property-based invariants for TimelineBuilder (seed 89c61672553d).
final class D0701TimelineBuilderTests: XCTestCase {
    private let seed = "89c61672553d"

    func testProperty_invariantsHold() {
        var rng = Phase2RNG(seed: seed)
        for _ in 0..<15 {
            _ = rng.nextInt(upperBound: 100)
            XCTAssertTrue(TimelineBuilder.propertyInvariantsHold())
        }
    }

    func testProperty_rngDeterministic() {
        var a = Phase2RNG(seed: seed)
        var b = Phase2RNG(seed: seed)
        XCTAssertEqual(a.nextUInt64(), b.nextUInt64())
    }

    func testProperty_phase2TechniqueInvariant() {
        XCTAssertTrue(Phase2Techniques.propertyInvariantHolds(iterations: 10) { _ in TimelineBuilder.propertyInvariantsHold() })
    }
}
