import XCTest
@testable import MnemoOrchestrator

/// D-0501: property-based invariants for Provenance (seed a384cf7a8a6b).
final class D0501ProvenanceTests: XCTestCase {
    private let seed = "a384cf7a8a6b"

    func testProperty_invariantsHold() {
        var rng = Phase2RNG(seed: seed)
        for _ in 0..<15 {
            _ = rng.nextInt(upperBound: 100)
            XCTAssertTrue(Provenance.propertyInvariantsHold())
        }
    }

    func testProperty_rngDeterministic() {
        var a = Phase2RNG(seed: seed)
        var b = Phase2RNG(seed: seed)
        XCTAssertEqual(a.nextUInt64(), b.nextUInt64())
    }

    func testProperty_phase2TechniqueInvariant() {
        XCTAssertTrue(Phase2Techniques.propertyInvariantHolds(iterations: 10) { _ in Provenance.propertyInvariantsHold() })
    }

    func testFromAnswer_unsupportedHasNoSource() {
        let sources = [SourceCard(docId: "d", path: "/a.md", title: "A", relevance: 0.9)]
        let verdicts = Provenance.fromAnswer("Hallucinated.", unsupported: [0], sources: sources)
        XCTAssertNil(verdicts[0].bestSource)
        XCTAssertFalse(verdicts[0].supported)
    }
}
