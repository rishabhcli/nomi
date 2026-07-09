import XCTest
@testable import MnemoOrchestrator

/// D-0547: router escalation boundaries for TimeWindow (seed 8cc3253c442e).
final class D0547TimeWindowTests: XCTestCase {
    private let seed = "8cc3253c442e"

    func testRouter_escalationNeutral() {
        XCTAssertTrue(TimeWindow.needsRouterEscalationNeutral())
    }

    func testRouter_escalationEventsRenderable() {
        let events = TimeWindow.routerEscalationEvents()
        if !events.isEmpty { XCTAssertTrue(Phase2TestSupport.isRenderable(events)) }
    }

    func testRouter_coverageEscalateBounded() {
        let base = SearchRequest(q: "q", searchMode: "memories", rerank: true,
                                 threshold: 0.5, limit: 10, container: "mnemo")
        let esc = Coverage.escalate(base)
        XCTAssertEqual(esc.searchMode, "hybrid")
    }
}
