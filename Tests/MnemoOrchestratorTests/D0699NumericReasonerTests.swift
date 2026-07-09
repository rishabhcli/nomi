import XCTest
@testable import MnemoOrchestrator

/// D-0699: QueryEvent ordering guarantees for NumericReasoner (seed 84ae278c1757).
final class D0699NumericReasonerTests: XCTestCase {
    private let seed = "84ae278c1757"

    func testOrdering_lifecycleValid() {
        let events = NumericReasoner.orderedLifecycleEvents()
        XCTAssertTrue(NumericReasoner.eventOrderingValid(events))
    }

    func testOrdering_phase2Lifecycle() {
        XCTAssertTrue(Phase2Techniques.lifecycleOrderingValid(
            NumericReasoner.lifecycleEvents(branch: .routeAmbiguity)))
    }

    func testOrdering_emptyEvidenceSourcesFirst() {
        let events = NumericReasoner.lifecycleEvents(branch: .emptyEvidence)
        let sIdx = events.firstIndex { if case .sources = $0 { true } else { false } }
        let tIdx = events.firstIndex { if case .token = $0 { true } else { false } }
        if let s = sIdx, let t = tIdx { XCTAssertLessThan(s, t) }
    }
}
