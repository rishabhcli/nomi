import XCTest
@testable import MnemoOrchestrator

/// D-0721: property-based invariants for CitationVerifier (seed a7cc96153b01).
final class D0721CitationVerifierTests: XCTestCase {
    private let seed = "a7cc96153b01"

    func testProperty_invariantsHold() {
        var rng = Phase2RNG(seed: seed)
        for _ in 0..<15 {
            _ = rng.nextInt(upperBound: 100)
            XCTAssertTrue(CitationVerifier.propertyInvariantsHold())
        }
    }

    func testProperty_rngDeterministic() {
        var a = Phase2RNG(seed: seed)
        var b = Phase2RNG(seed: seed)
        XCTAssertEqual(a.nextUInt64(), b.nextUInt64())
    }

    func testProperty_phase2TechniqueInvariant() {
        XCTAssertTrue(Phase2Techniques.propertyInvariantHolds(iterations: 10) { _ in CitationVerifier.propertyInvariantsHold() })
    }
}
