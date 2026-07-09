import XCTest
@testable import MnemoOrchestrator

/// D-0567: router escalation boundaries for EngineIntegration (seed 2474b339a77f).
final class D0567EngineIntegrationTests: XCTestCase {
    private let seed = "2474b339a77f"

    func testRouter_escalationNeutral() {
        XCTAssertTrue(EngineIntegration.needsRouterEscalationNeutral())
    }

    func testRouter_escalationEventsRenderable() {
        let events = EngineIntegration.routerEscalationEvents()
        if !events.isEmpty { XCTAssertTrue(Phase2TestSupport.isRenderable(events)) }
    }

    func testRouter_coverageEscalateBounded() {
        let base = SearchRequest(q: "q", searchMode: "memories", rerank: true,
                                 threshold: 0.5, limit: 10, container: "mnemo")
        let esc = Coverage.escalate(base)
        XCTAssertEqual(esc.searchMode, "hybrid")
    }
}
