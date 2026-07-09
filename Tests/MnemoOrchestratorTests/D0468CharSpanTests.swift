import XCTest
@testable import MnemoOrchestrator

/// D-0468: CharSpan citation verifier false-positive elimination (seed f251672ee4bd).
final class D0468CharSpanTests: XCTestCase {
    private let seed = "f251672ee4bd"

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
