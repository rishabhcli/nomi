import XCTest
@testable import MnemoOrchestrator

/// D-0587: router escalation boundaries for EgressGuard (seed 32a933712550).
final class D0587EgressGuardTests: XCTestCase {
    private let seed = "32a933712550"

    func testRouter_escalationNeutral() {
        XCTAssertTrue(EgressGuard.needsRouterEscalationNeutral())
    }

    func testRouter_escalationEventsRenderable() {
        let events = EgressGuard.routerEscalationEvents()
        if !events.isEmpty { XCTAssertTrue(Phase2TestSupport.isRenderable(events)) }
    }

    func testRouter_coverageEscalateBounded() {
        let base = SearchRequest(q: "q", searchMode: "memories", rerank: true,
                                 threshold: 0.5, limit: 10, container: "mnemo")
        let esc = Coverage.escalate(base)
        XCTAssertEqual(esc.searchMode, "hybrid")
    }
}
