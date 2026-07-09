import XCTest
@testable import MnemoOrchestrator

/// D-0238: QueryHistory TerminalState exhaustiveness (seed c6955dae9e5b).
final class D0238QueryHistoryTests: XCTestCase {
    private let seed = "c6955dae9e5b"

    func testTerminalStatesExhaustive() {
        XCTAssertTrue(QueryHistory.terminalStatesExhaustive())
        for t in QueryHistory.allTerminalStates() {
            XCTAssertFalse(NotchReducer.message(for: t).isEmpty)
        }
    }
}
