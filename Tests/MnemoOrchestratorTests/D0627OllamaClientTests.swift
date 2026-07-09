import XCTest
@testable import MnemoOrchestrator

/// D-0627: router escalation boundaries for OllamaClient (seed 4d34aa3ba29d).
final class D0627OllamaClientTests: XCTestCase {
    private let seed = "4d34aa3ba29d"

    func testRouter_escalationNeutral() {
        XCTAssertTrue(OllamaClient.needsRouterEscalationNeutral())
    }

    func testRouter_escalationEventsRenderable() {
        let events = OllamaClient.routerEscalationEvents()
        if !events.isEmpty { XCTAssertTrue(Phase2TestSupport.isRenderable(events)) }
    }

    func testRouter_coverageEscalateBounded() {
        let base = SearchRequest(q: "q", searchMode: "memories", rerank: true,
                                 threshold: 0.5, limit: 10, container: "mnemo")
        let esc = Coverage.escalate(base)
        XCTAssertEqual(esc.searchMode, "hybrid")
    }
}
