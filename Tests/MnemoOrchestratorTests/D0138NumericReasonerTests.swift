import XCTest
@testable import MnemoOrchestrator

/// D-0138: NumericReasoner TerminalState exhaustiveness (seed 1810fba473ae).
final class D0138NumericReasonerTests: XCTestCase {
    private let seed = "1810fba473ae"

    func testTerminalStatesExhaustive() {
        XCTAssertTrue(NumericReasoner.terminalStatesExhaustive())
        for t in NumericReasoner.allTerminalStates() {
            XCTAssertFalse(NotchReducer.message(for: t).isEmpty)
        }
    }
}
