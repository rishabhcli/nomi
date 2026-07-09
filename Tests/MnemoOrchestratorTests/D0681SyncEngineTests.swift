import XCTest
@testable import MnemoOrchestrator

/// D-0681: property-based invariants for SyncEngine (seed 2f4ccf907a72).
final class D0681SyncEngineTests: XCTestCase {
    private let seed = "2f4ccf907a72"

    func testProperty_invariantsHold() {
        var rng = Phase2RNG(seed: seed)
        for _ in 0..<15 {
            _ = rng.nextInt(upperBound: 100)
            XCTAssertTrue(SyncEngine.propertyInvariantsHold())
        }
    }

    func testProperty_rngDeterministic() {
        var a = Phase2RNG(seed: seed)
        var b = Phase2RNG(seed: seed)
        XCTAssertEqual(a.nextUInt64(), b.nextUInt64())
    }

    func testProperty_phase2TechniqueInvariant() {
        XCTAssertTrue(Phase2Techniques.propertyInvariantHolds(iterations: 10) { _ in SyncEngine.propertyInvariantsHold() })
    }
}
