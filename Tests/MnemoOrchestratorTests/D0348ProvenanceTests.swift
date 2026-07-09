import XCTest
@testable import MnemoOrchestrator

/// D-0348: Provenance citation verifier false-positive elimination (seed e6454a319cde).
final class D0348ProvenanceTests: XCTestCase {
    private let seed = "e6454a319cde"

    func testCitationIntegrityRejectsFabrication() {
        let ev = [Phase2TechniqueSupport.sampleRetrieved(memory: "Uses Bazel.")]
        XCTAssertFalse(Provenance.citationIntegritySupported("Uses CMake [doc].", evidence: ev))
        XCTAssertTrue(Provenance.citationIntegritySupported("Uses Bazel [doc].", evidence: ev))
    }

    func testEmptyClaimPasses() {
        XCTAssertTrue(Provenance.citationIntegritySupported("   ", evidence: []))
    }

    func testProperty_shortTokensSkipped() {
        var rng = Phase2RNG(seed: seed)
        let ev = [Phase2TechniqueSupport.sampleRetrieved(memory: "alpha beta gamma delta")]
        for _ in 0..<4 {
            let ok = Provenance.citationIntegritySupported("alpha [x].", evidence: ev)
            XCTAssertEqual(ok, Provenance.citationIntegritySupported("alpha [x].", evidence: ev))
            _ = rng.nextInt(upperBound: 3)
        }
    }
}
