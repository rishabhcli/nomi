import XCTest
@testable import MnemoOrchestrator

/// D-0607: router escalation boundaries for LocalExtractor (seed f20eb48be645).
final class D0607LocalExtractorTests: XCTestCase {
    private let seed = "f20eb48be645"

    func testRouter_escalationNeutral() {
        XCTAssertTrue(LocalExtractor.needsRouterEscalationNeutral())
    }

    func testRouter_escalationEventsRenderable() {
        let events = LocalExtractor.routerEscalationEvents()
        if !events.isEmpty { XCTAssertTrue(Phase2TestSupport.isRenderable(events)) }
    }

    func testRouter_coverageEscalateBounded() {
        let base = SearchRequest(q: "q", searchMode: "memories", rerank: true,
                                 threshold: 0.5, limit: 10, container: "mnemo")
        let esc = Coverage.escalate(base)
        XCTAssertEqual(esc.searchMode, "hybrid")
    }
}
