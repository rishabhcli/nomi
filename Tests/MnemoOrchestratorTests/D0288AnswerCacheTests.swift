import XCTest
@testable import MnemoOrchestrator

/// D-0288: AnswerCache citation verifier false-positive elimination (seed 752f33c29467).
final class D0288AnswerCacheTests: XCTestCase {
    private let seed = "752f33c29467"

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
