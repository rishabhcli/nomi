import XCTest
@testable import MnemoOrchestrator

/// D-0581: property-based invariants for MemoryDynamics (seed e83e4a9fede4).
final class D0581MemoryDynamicsTests: XCTestCase {
    private let seed = "e83e4a9fede4"

    func testProperty_invariantsHold() {
        var rng = Phase2RNG(seed: seed)
        for _ in 0..<15 {
            _ = rng.nextInt(upperBound: 100)
            XCTAssertTrue(MemoryDynamics.propertyInvariantsHold())
        }
    }

    func testProperty_rngDeterministic() {
        var a = Phase2RNG(seed: seed)
        var b = Phase2RNG(seed: seed)
        XCTAssertEqual(a.nextUInt64(), b.nextUInt64())
    }

    func testProperty_phase2TechniqueInvariant() {
        XCTAssertTrue(Phase2Techniques.propertyInvariantHolds(iterations: 10) { _ in MemoryDynamics.propertyInvariantsHold() })
    }
}
