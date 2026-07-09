import XCTest
@testable import MnemoOrchestrator

/// D-0552: numeric synthesis distractor immunity for Provenance (seed 0448f27bcebf).
final class D0552ProvenanceTests: XCTestCase {
    private let seed = "0448f27bcebf"

    func testNumeric_rejectsDistractor() {
        XCTAssertTrue(Provenance.rejectsNumericDistractor("budget 50000 in 2020", question: "what year?"))
    }

    func testNumeric_phase2Immune() {
        XCTAssertTrue(Phase2Techniques.immuneToNumericDistractor(
            claim: "budget 2020", evidence: Phase2TestSupport.sampleEvidence, distractor: "1999"))
    }

    func testNumeric_rngIterations() {
        var rng = Phase2RNG(seed: seed)
        XCTAssertGreaterThan(rng.nextInt(upperBound: 100), -1)
    }

    func testFromAnswer_unsupportedHasNoSource() {
        let sources = [SourceCard(docId: "d", path: "/a.md", title: "A", relevance: 0.9)]
        let verdicts = Provenance.fromAnswer("Hallucinated.", unsupported: [0], sources: sources)
        XCTAssertNil(verdicts[0].bestSource)
        XCTAssertFalse(verdicts[0].supported)
    }
}
