import XCTest
@testable import MnemoOrchestrator

/// D-0647: router escalation boundaries for PersonalRanker (seed e82d6d39022b).
final class D0647PersonalRankerTests: XCTestCase {
    private let seed = "e82d6d39022b"

    func testRouter_escalationNeutral() {
        XCTAssertTrue(PersonalRanker.needsRouterEscalationNeutral())
    }

    func testRouter_escalationEventsRenderable() {
        let events = PersonalRanker.routerEscalationEvents()
        if !events.isEmpty { XCTAssertTrue(Phase2TestSupport.isRenderable(events)) }
    }

    func testRouter_coverageEscalateBounded() {
        let base = SearchRequest(q: "q", searchMode: "memories", rerank: true,
                                 threshold: 0.5, limit: 10, container: "mnemo")
        let esc = Coverage.escalate(base)
        XCTAssertEqual(esc.searchMode, "hybrid")
    }
}
