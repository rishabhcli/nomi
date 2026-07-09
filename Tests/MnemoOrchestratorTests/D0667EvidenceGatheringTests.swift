import XCTest
@testable import MnemoOrchestrator

/// D-0667: router escalation boundaries for EvidenceGathering (seed 06bf373081cf).
final class D0667EvidenceGatheringTests: XCTestCase {
    private let seed = "06bf373081cf"

    func testRouter_escalationNeutral() {
        XCTAssertTrue(EvidenceGathering.needsRouterEscalationNeutral())
    }

    func testRouter_escalationEventsRenderable() {
        let events = EvidenceGathering.routerEscalationEvents()
        if !events.isEmpty { XCTAssertTrue(Phase2TestSupport.isRenderable(events)) }
    }

    func testRouter_coverageEscalateBounded() {
        let base = SearchRequest(q: "q", searchMode: "memories", rerank: true,
                                 threshold: 0.5, limit: 10, container: "mnemo")
        let esc = Coverage.escalate(base)
        XCTAssertEqual(esc.searchMode, "hybrid")
    }
}
