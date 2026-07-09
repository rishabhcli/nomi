import XCTest
@testable import MnemoOrchestrator

/// D-0705: cache poisoning resistance for Provenance (seed 8be41827616d).
final class D0705ProvenanceTests: XCTestCase {
    private let seed = "8be41827616d"

    func testCache_resistsPoisonKeys() {
        XCTAssertFalse(Provenance.resistsCachePoisoning("api.supermemory.ai"))
        XCTAssertTrue(Provenance.resistsCachePoisoning("127.0.0.1"))
        XCTAssertFalse(Provenance.resistsCachePoisoning("\0injected"))
    }

    func testCache_phase2PoisonRejected() {
        XCTAssertTrue(Phase2Techniques.cachePoisonKeyRejected("\0bad"))
    }

    func testCache_keySeparatesContainer() {
        let k1 = Provenance.cacheKey(query: "q", container: "a", extra: "1")
        let k2 = Provenance.cacheKey(query: "q", container: "b", extra: "1")
        XCTAssertNotEqual(k1, k2)
    }

    func testFromAnswer_unsupportedHasNoSource() {
        let sources = [SourceCard(docId: "d", path: "/a.md", title: "A", relevance: 0.9)]
        let verdicts = Provenance.fromAnswer("Hallucinated.", unsupported: [0], sources: sources)
        XCTAssertNil(verdicts[0].bestSource)
        XCTAssertFalse(verdicts[0].supported)
    }
}
