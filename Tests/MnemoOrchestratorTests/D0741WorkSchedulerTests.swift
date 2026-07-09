import XCTest
@testable import MnemoOrchestrator

/// D-0741: property-based invariants for WorkScheduler (seed 96ad6d16c449).
final class D0741WorkSchedulerTests: XCTestCase {
    private let seed = "96ad6d16c449"

    func testProperty_invariantsHold() {
        var rng = Phase2RNG(seed: seed)
        for _ in 0..<15 {
            _ = rng.nextInt(upperBound: 100)
            XCTAssertTrue(WorkScheduler.propertyInvariantsHold())
        }
    }

    func testProperty_rngDeterministic() {
        var a = Phase2RNG(seed: seed)
        var b = Phase2RNG(seed: seed)
        XCTAssertEqual(a.nextUInt64(), b.nextUInt64())
    }

    func testProperty_phase2TechniqueInvariant() {
        XCTAssertTrue(Phase2Techniques.propertyInvariantHolds(iterations: 10) { _ in WorkScheduler.propertyInvariantsHold() })
    }
}
