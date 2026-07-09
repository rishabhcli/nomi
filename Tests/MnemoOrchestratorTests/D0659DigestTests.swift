import XCTest
@testable import MnemoOrchestrator

/// D-0659: QueryEvent ordering guarantees for Digest (seed 4bf5739a0440).
final class D0659DigestTests: XCTestCase {
    private let seed = "4bf5739a0440"

    func testOrdering_lifecycleValid() {
        let events = Digest.orderedLifecycleEvents()
        XCTAssertTrue(Digest.eventOrderingValid(events))
    }

    func testOrdering_phase2Lifecycle() {
        XCTAssertTrue(Phase2Techniques.lifecycleOrderingValid(
            Digest.lifecycleEvents(branch: .routeAmbiguity)))
    }

    func testOrdering_emptyEvidenceSourcesFirst() {
        let events = Digest.lifecycleEvents(branch: .emptyEvidence)
        let sIdx = events.firstIndex { if case .sources = $0 { true } else { false } }
        let tIdx = events.firstIndex { if case .token = $0 { true } else { false } }
        if let s = sIdx, let t = tIdx { XCTAssertLessThan(s, t) }
    }
}
