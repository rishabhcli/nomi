import XCTest
@testable import MnemoOrchestrator

/// D-0707: router escalation boundaries for EntityExtractor (seed a0496de0b4d4).
final class D0707EntityExtractorTests: XCTestCase {
    private let seed = "a0496de0b4d4"

    func testRouter_escalationNeutral() {
        XCTAssertTrue(EntityExtractor.needsRouterEscalationNeutral())
    }

    func testRouter_escalationEventsRenderable() {
        let events = EntityExtractor.routerEscalationEvents()
        if !events.isEmpty { XCTAssertTrue(Phase2TestSupport.isRenderable(events)) }
    }

    func testRouter_coverageEscalateBounded() {
        let base = SearchRequest(q: "q", searchMode: "memories", rerank: true,
                                 threshold: 0.5, limit: 10, container: "mnemo")
        let esc = Coverage.escalate(base)
        XCTAssertEqual(esc.searchMode, "hybrid")
    }

    func testEntities_extractsMidSentence() {
        let ents = EntityExtractor.entities(in: "Notes mention Rust often.")
        XCTAssertTrue(ents.contains("Rust"))
    }
}
