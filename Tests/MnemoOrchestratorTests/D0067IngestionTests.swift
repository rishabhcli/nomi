import XCTest
@testable import MnemoOrchestrator

/// D-0067: Ingestion router escalation boundaries (seed 9f27b9e42b82).
final class D0067IngestionTests: XCTestCase {
    private let seed = "9f27b9e42b82"

    func testRouterEscalationBoundaries() {
        XCTAssertFalse(Ingestion.needsRouterEscalationNeutral())
        let events = Ingestion.routerEscalationEvents()
        var state = NotchState(phase: .input, query: "q", answer: "", sources: [])
        for e in events { state = NotchReducer.apply(e, to: state) }
        if !events.isEmpty { XCTAssertFalse(state.reasoning.isEmpty) }
    }
}
