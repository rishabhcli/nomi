import XCTest
@testable import MnemoOrchestrator

/// D-0047: Digest router escalation boundaries (seed f6685efbb838).
final class D0047DigestTests: XCTestCase {
    private let seed = "f6685efbb838"

    func testRouterEscalationBoundaries() {
        XCTAssertFalse(Digest.needsRouterEscalationNeutral())
        let events = Digest.routerEscalationEvents()
        var state = NotchState(phase: .input, query: "q", answer: "", sources: [])
        for e in events { state = NotchReducer.apply(e, to: state) }
        if !events.isEmpty { XCTAssertFalse(state.reasoning.isEmpty) }
    }
}
