import XCTest
@testable import MnemoOrchestrator

/// D-0247: CommandParser router escalation boundaries (seed 8e4848b465d8).
final class D0247CommandParserTests: XCTestCase {
    private let seed = "8e4848b465d8"

    func testRouterEscalationBoundaries() {
        XCTAssertFalse(CommandParser.needsRouterEscalationNeutral())
        let events = CommandParser.routerEscalationEvents()
        var state = NotchState(phase: .input, query: "q", answer: "", sources: [])
        for e in events { state = NotchReducer.apply(e, to: state) }
        if !events.isEmpty { XCTAssertFalse(state.reasoning.isEmpty) }
    }
}
