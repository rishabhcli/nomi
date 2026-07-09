import XCTest
@testable import MnemoOrchestrator

/// D-0641: property-based invariants for QueryRewriter (seed 9fb74c8f5598).
final class D0641QueryRewriterTests: XCTestCase {
    private let seed = "9fb74c8f5598"

    func testProperty_invariantsHold() {
        var rng = Phase2RNG(seed: seed)
        for _ in 0..<15 {
            _ = rng.nextInt(upperBound: 100)
            XCTAssertTrue(QueryRewriter.propertyInvariantsHold())
        }
    }

    func testProperty_rngDeterministic() {
        var a = Phase2RNG(seed: seed)
        var b = Phase2RNG(seed: seed)
        XCTAssertEqual(a.nextUInt64(), b.nextUInt64())
    }

    func testProperty_phase2TechniqueInvariant() {
        XCTAssertTrue(Phase2Techniques.propertyInvariantHolds(iterations: 10) { _ in QueryRewriter.propertyInvariantsHold() })
    }
}
