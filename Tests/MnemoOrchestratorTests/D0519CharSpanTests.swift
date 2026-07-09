import XCTest
@testable import MnemoOrchestrator

/// D-0519: QueryEvent ordering guarantees for CharSpan (seed 2ce28a921ccd).
final class D0519CharSpanTests: XCTestCase {
    private let seed = "2ce28a921ccd"

    func testOrdering_lifecycleValid() {
        let events = CharSpan.orderedLifecycleEvents()
        XCTAssertTrue(CharSpan.eventOrderingValid(events))
    }

    func testOrdering_phase2Lifecycle() {
        XCTAssertTrue(Phase2Techniques.lifecycleOrderingValid(
            CharSpan.lifecycleEvents(branch: .routeAmbiguity)))
    }

    func testOrdering_emptyEvidenceSourcesFirst() {
        let events = CharSpan.lifecycleEvents(branch: .emptyEvidence)
        let sIdx = events.firstIndex { if case .sources = $0 { true } else { false } }
        let tIdx = events.firstIndex { if case .token = $0 { true } else { false } }
        if let s = sIdx, let t = tIdx { XCTAssertLessThan(s, t) }
    }
}
