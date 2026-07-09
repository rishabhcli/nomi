import XCTest
@testable import MnemoOrchestrator

/// D-0599: QueryEvent ordering guarantees for TimelineBuilder (seed acc03d41ec82).
final class D0599TimelineBuilderTests: XCTestCase {
    private let seed = "acc03d41ec82"

    func testOrdering_lifecycleValid() {
        let events = TimelineBuilder.orderedLifecycleEvents()
        XCTAssertTrue(TimelineBuilder.eventOrderingValid(events))
    }

    func testOrdering_phase2Lifecycle() {
        XCTAssertTrue(Phase2Techniques.lifecycleOrderingValid(
            TimelineBuilder.lifecycleEvents(branch: .routeAmbiguity)))
    }

    func testOrdering_emptyEvidenceSourcesFirst() {
        let events = TimelineBuilder.lifecycleEvents(branch: .emptyEvidence)
        let sIdx = events.firstIndex { if case .sources = $0 { true } else { false } }
        let tIdx = events.firstIndex { if case .token = $0 { true } else { false } }
        if let s = sIdx, let t = tIdx { XCTAssertLessThan(s, t) }
    }
}
