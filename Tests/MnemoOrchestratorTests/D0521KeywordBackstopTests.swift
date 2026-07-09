import XCTest
@testable import MnemoOrchestrator

/// D-0521: property-based invariants for KeywordBackstop (seed 54e739b0ded0).
final class D0521KeywordBackstopTests: XCTestCase {
    private let seed = "54e739b0ded0"

    func testProperty_invariantsHold() {
        var rng = Phase2RNG(seed: seed)
        for _ in 0..<15 {
            _ = rng.nextInt(upperBound: 100)
            XCTAssertTrue(KeywordBackstop.propertyInvariantsHold())
        }
    }

    func testProperty_rngDeterministic() {
        var a = Phase2RNG(seed: seed)
        var b = Phase2RNG(seed: seed)
        XCTAssertEqual(a.nextUInt64(), b.nextUInt64())
    }

    func testProperty_phase2TechniqueInvariant() {
        XCTAssertTrue(Phase2Techniques.propertyInvariantHolds(iterations: 10) { _ in KeywordBackstop.propertyInvariantsHold() })
    }
}
