import XCTest
@testable import MnemoOrchestrator

/// D-0687: router escalation boundaries for Inspector (seed f7da95ead24f).
final class D0687InspectorTests: XCTestCase {
    private let seed = "f7da95ead24f"

    func testRouter_escalationNeutral() {
        XCTAssertTrue(Inspector.needsRouterEscalationNeutral())
    }

    func testRouter_escalationEventsRenderable() {
        let events = Inspector.routerEscalationEvents()
        if !events.isEmpty { XCTAssertTrue(Phase2TestSupport.isRenderable(events)) }
    }

    func testRouter_coverageEscalateBounded() {
        let base = SearchRequest(q: "q", searchMode: "memories", rerank: true,
                                 threshold: 0.5, limit: 10, container: "mnemo")
        let esc = Coverage.escalate(base)
        XCTAssertEqual(esc.searchMode, "hybrid")
    }
}
