import XCTest
@testable import MnemoOrchestrator

/// D-0541: property-based invariants for ScopeClassifier (seed 210ddf388c2a).
final class D0541ScopeClassifierTests: XCTestCase {
    private let seed = "210ddf388c2a"

    func testProperty_invariantsHold() {
        var rng = Phase2RNG(seed: seed)
        for _ in 0..<15 {
            _ = rng.nextInt(upperBound: 100)
            XCTAssertTrue(ScopeClassifier.propertyInvariantsHold())
        }
    }

    func testProperty_rngDeterministic() {
        var a = Phase2RNG(seed: seed)
        var b = Phase2RNG(seed: seed)
        XCTAssertEqual(a.nextUInt64(), b.nextUInt64())
    }

    func testProperty_phase2TechniqueInvariant() {
        XCTAssertTrue(Phase2Techniques.propertyInvariantHolds(iterations: 10) { _ in ScopeClassifier.propertyInvariantsHold() })
    }
}
