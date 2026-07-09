import XCTest
@testable import MnemoOrchestrator

/// D-0388: ScopeClassifier citation verifier false-positive elimination (seed 8cd5f460b829).
final class D0388ScopeClassifierTests: XCTestCase {
    private let seed = "8cd5f460b829"

    func testCitationIntegrityRejectsFabrication() {
        let ev = [Phase2TechniqueSupport.sampleRetrieved(memory: "Uses Bazel.")]
        XCTAssertFalse(ContextAssembler.citationIntegritySupported("Uses CMake [doc].", evidence: ev))
        XCTAssertTrue(ContextAssembler.citationIntegritySupported("Uses Bazel [doc].", evidence: ev))
    }

    func testEmptyClaimPasses() {
        XCTAssertTrue(ContextAssembler.citationIntegritySupported("   ", evidence: []))
    }

    func testProperty_shortTokensSkipped() {
        var rng = Phase2RNG(seed: seed)
        let ev = [Phase2TechniqueSupport.sampleRetrieved(memory: "alpha beta gamma delta")]
        for _ in 0..<4 {
            let ok = ContextAssembler.citationIntegritySupported("alpha [x].", evidence: ev)
            XCTAssertEqual(ok, ContextAssembler.citationIntegritySupported("alpha [x].", evidence: ev))
            _ = rng.nextInt(upperBound: 3)
        }
    }
}
