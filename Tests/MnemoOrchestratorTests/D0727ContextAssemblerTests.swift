import XCTest
@testable import MnemoOrchestrator

/// D-0727: router escalation boundaries for ContextAssembler (seed da308c3fe09e).
final class D0727ContextAssemblerTests: XCTestCase {
    private let seed = "da308c3fe09e"

    func testRouter_escalationNeutral() {
        XCTAssertTrue(ContextAssembler.needsRouterEscalationNeutral())
    }

    func testRouter_escalationEventsRenderable() {
        let events = ContextAssembler.routerEscalationEvents()
        if !events.isEmpty { XCTAssertTrue(Phase2TestSupport.isRenderable(events)) }
    }

    func testRouter_coverageEscalateBounded() {
        let base = SearchRequest(q: "q", searchMode: "memories", rerank: true,
                                 threshold: 0.5, limit: 10, container: "mnemo")
        let esc = Coverage.escalate(base)
        XCTAssertEqual(esc.searchMode, "hybrid")
    }
}
