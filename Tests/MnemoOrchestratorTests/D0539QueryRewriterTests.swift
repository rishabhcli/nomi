import XCTest
@testable import MnemoOrchestrator

/// D-0539: QueryEvent ordering guarantees for QueryRewriter (seed 227c08b16a57).
final class D0539QueryRewriterTests: XCTestCase {
    private let seed = "227c08b16a57"

    func testOrdering_lifecycleValid() {
        let events = QueryRewriter.orderedLifecycleEvents()
        XCTAssertTrue(QueryRewriter.eventOrderingValid(events))
    }

    func testOrdering_phase2Lifecycle() {
        XCTAssertTrue(Phase2Techniques.lifecycleOrderingValid(
            QueryRewriter.lifecycleEvents(branch: .routeAmbiguity)))
    }

    func testOrdering_emptyEvidenceSourcesFirst() {
        let events = QueryRewriter.lifecycleEvents(branch: .emptyEvidence)
        let sIdx = events.firstIndex { if case .sources = $0 { true } else { false } }
        let tIdx = events.firstIndex { if case .token = $0 { true } else { false } }
        if let s = sIdx, let t = tIdx { XCTAssertLessThan(s, t) }
    }
}
