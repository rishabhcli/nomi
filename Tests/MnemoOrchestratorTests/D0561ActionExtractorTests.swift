import XCTest
@testable import MnemoOrchestrator

/// D-0561: property-based invariants for ActionExtractor (seed 8b473d807655).
final class D0561ActionExtractorTests: XCTestCase {
    private let seed = "8b473d807655"

    func testProperty_invariantsHold() {
        var rng = Phase2RNG(seed: seed)
        for _ in 0..<15 {
            _ = rng.nextInt(upperBound: 100)
            XCTAssertTrue(ActionExtractor.propertyInvariantsHold())
        }
    }

    func testProperty_rngDeterministic() {
        var a = Phase2RNG(seed: seed)
        var b = Phase2RNG(seed: seed)
        XCTAssertEqual(a.nextUInt64(), b.nextUInt64())
    }

    func testProperty_phase2TechniqueInvariant() {
        XCTAssertTrue(Phase2Techniques.propertyInvariantHolds(iterations: 10) { _ in ActionExtractor.propertyInvariantsHold() })
    }
}
