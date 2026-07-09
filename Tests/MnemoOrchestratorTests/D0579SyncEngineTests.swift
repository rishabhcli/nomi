import XCTest
@testable import MnemoOrchestrator

/// D-0579: QueryEvent ordering guarantees for SyncEngine (seed b9681562e00f).
final class D0579SyncEngineTests: XCTestCase {
    private let seed = "b9681562e00f"

    func testOrdering_lifecycleValid() {
        let events = SyncEngine.orderedLifecycleEvents()
        XCTAssertTrue(SyncEngine.eventOrderingValid(events))
    }

    func testOrdering_phase2Lifecycle() {
        XCTAssertTrue(Phase2Techniques.lifecycleOrderingValid(
            SyncEngine.lifecycleEvents(branch: .routeAmbiguity)))
    }

    func testOrdering_emptyEvidenceSourcesFirst() {
        let events = SyncEngine.lifecycleEvents(branch: .emptyEvidence)
        let sIdx = events.firstIndex { if case .sources = $0 { true } else { false } }
        let tIdx = events.firstIndex { if case .token = $0 { true } else { false } }
        if let s = sIdx, let t = tIdx { XCTAssertLessThan(s, t) }
    }
}
