import XCTest
@testable import MnemoOrchestrator

/// D-0619: QueryEvent ordering guarantees for CitationVerifier (seed b6a2c03579f5).
final class D0619CitationVerifierTests: XCTestCase {
    private let seed = "b6a2c03579f5"

    func testOrdering_lifecycleValid() {
        let events = CitationVerifier.orderedLifecycleEvents()
        XCTAssertTrue(CitationVerifier.eventOrderingValid(events))
    }

    func testOrdering_phase2Lifecycle() {
        XCTAssertTrue(Phase2Techniques.lifecycleOrderingValid(
            CitationVerifier.lifecycleEvents(branch: .routeAmbiguity)))
    }

    func testOrdering_emptyEvidenceSourcesFirst() {
        let events = CitationVerifier.lifecycleEvents(branch: .emptyEvidence)
        let sIdx = events.firstIndex { if case .sources = $0 { true } else { false } }
        let tIdx = events.firstIndex { if case .token = $0 { true } else { false } }
        if let s = sIdx, let t = tIdx { XCTAssertLessThan(s, t) }
    }
}
