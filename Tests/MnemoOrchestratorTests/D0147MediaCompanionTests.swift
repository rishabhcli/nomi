import XCTest
@testable import MnemoOrchestrator

/// D-0147: MediaCompanion router escalation boundaries (seed c50df3d03755).
final class D0147MediaCompanionTests: XCTestCase {
    private let seed = "c50df3d03755"

    func testRouterEscalationBoundaries() {
        XCTAssertFalse(MediaCompanion.needsRouterEscalationNeutral())
        let events = MediaCompanion.routerEscalationEvents()
        var state = NotchState(phase: .input, query: "q", answer: "", sources: [])
        for e in events { state = NotchReducer.apply(e, to: state) }
        if !events.isEmpty { XCTAssertFalse(state.reasoning.isEmpty) }
    }
}
