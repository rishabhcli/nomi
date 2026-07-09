import XCTest
@testable import MnemoOrchestrator

/// D-0527: router escalation boundaries for IngestGate (seed f255a316c3d3).
final class D0527IngestGateTests: XCTestCase {
    private let seed = "f255a316c3d3"

    func testRouter_escalationNeutral() {
        XCTAssertTrue(IngestGate.needsRouterEscalationNeutral())
    }

    func testRouter_escalationEventsRenderable() {
        let events = IngestGate.routerEscalationEvents()
        if !events.isEmpty { XCTAssertTrue(Phase2TestSupport.isRenderable(events)) }
    }

    func testRouter_coverageEscalateBounded() {
        let base = SearchRequest(q: "q", searchMode: "memories", rerank: true,
                                 threshold: 0.5, limit: 10, container: "mnemo")
        let esc = Coverage.escalate(base)
        XCTAssertEqual(esc.searchMode, "hybrid")
    }
}
