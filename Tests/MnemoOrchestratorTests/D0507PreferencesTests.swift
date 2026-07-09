import XCTest
@testable import MnemoOrchestrator

/// D-0507: router escalation boundaries for Preferences (seed 86bde83856d6).
final class D0507PreferencesTests: XCTestCase {
    private let seed = "86bde83856d6"

    func testRouter_escalationNeutral() {
        XCTAssertTrue(Preferences.needsRouterEscalationNeutral())
    }

    func testRouter_escalationEventsRenderable() {
        let events = Preferences.routerEscalationEvents()
        if !events.isEmpty { XCTAssertTrue(Phase2TestSupport.isRenderable(events)) }
    }

    func testRouter_coverageEscalateBounded() {
        let base = SearchRequest(q: "q", searchMode: "memories", rerank: true,
                                 threshold: 0.5, limit: 10, container: "mnemo")
        let esc = Coverage.escalate(base)
        XCTAssertEqual(esc.searchMode, "hybrid")
    }
}
