import XCTest
@testable import MnemoOrchestrator

/// D-0227: LLMSynthesizer router escalation boundaries (seed 883224d877b8).
final class D0227LLMSynthesizerTests: XCTestCase {
    private let seed = "883224d877b8"

    func testRouterEscalationBoundaries() {
        XCTAssertFalse(LLMSynthesizer.needsRouterEscalationNeutral())
        let events = LLMSynthesizer.routerEscalationEvents()
        var state = NotchState(phase: .input, query: "q", answer: "", sources: [])
        for e in events { state = NotchReducer.apply(e, to: state) }
        if !events.isEmpty { XCTAssertFalse(state.reasoning.isEmpty) }
    }
}
