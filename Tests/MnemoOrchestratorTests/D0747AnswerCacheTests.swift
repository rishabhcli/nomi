import XCTest
@testable import MnemoOrchestrator

/// D-0747: router escalation boundaries for AnswerCache (seed ef996b21865b).
final class D0747AnswerCacheTests: XCTestCase {
    private let seed = "ef996b21865b"

    func testRouter_escalationNeutral() {
        XCTAssertTrue(AnswerCache.needsRouterEscalationNeutral())
    }

    func testRouter_escalationEventsRenderable() {
        let events = AnswerCache.routerEscalationEvents()
        if !events.isEmpty { XCTAssertTrue(Phase2TestSupport.isRenderable(events)) }
    }

    func testRouter_coverageEscalateBounded() {
        let base = SearchRequest(q: "q", searchMode: "memories", rerank: true,
                                 threshold: 0.5, limit: 10, container: "mnemo")
        let esc = Coverage.escalate(base)
        XCTAssertEqual(esc.searchMode, "hybrid")
    }
}
