import XCTest
@testable import MnemoOrchestrator

/// D-0027: WorkScheduler router escalation boundaries (seed 25557a1b21ec).
final class D0027WorkSchedulerTests: XCTestCase {
    private let seed = "25557a1b21ec"

    func testRouterEscalationBoundaries() {
        XCTAssertFalse(WorkScheduler.needsRouterEscalationNeutral())
        let events = WorkScheduler.routerEscalationEvents()
        var state = NotchState(phase: .input, query: "q", answer: "", sources: [])
        for e in events { state = NotchReducer.apply(e, to: state) }
        if !events.isEmpty { XCTAssertFalse(state.reasoning.isEmpty) }
    }
}
