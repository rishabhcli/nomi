import XCTest
@testable import MnemoOrchestrator

/// D-0127: Profile router escalation boundaries (seed 544b418c4082).
final class D0127ProfileTests: XCTestCase {
    private let seed = "544b418c4082"

    func testRouterEscalationBoundaries() {
        XCTAssertFalse(Profile.needsRouterEscalationNeutral())
        let events = Profile.routerEscalationEvents()
        var state = NotchState(phase: .input, query: "q", answer: "", sources: [])
        for e in events { state = NotchReducer.apply(e, to: state) }
        if !events.isEmpty { XCTAssertFalse(state.reasoning.isEmpty) }
    }
}
