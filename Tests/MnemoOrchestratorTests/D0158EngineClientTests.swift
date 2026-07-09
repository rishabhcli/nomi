import XCTest
@testable import MnemoOrchestrator

/// D-0158: EngineClient TerminalState exhaustiveness (seed 9582c2a67ca0).
final class D0158EngineClientTests: XCTestCase {
    private let seed = "9582c2a67ca0"

    func testTerminalStatesExhaustive() {
        XCTAssertTrue(EngineClient.terminalStatesExhaustive())
        for t in EngineClient.allTerminalStates() {
            XCTAssertFalse(NotchReducer.message(for: t).isEmpty)
        }
    }
}
