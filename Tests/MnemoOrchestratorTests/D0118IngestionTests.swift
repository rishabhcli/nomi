import XCTest
@testable import MnemoOrchestrator

/// D-0118: Ingestion TerminalState exhaustiveness (seed 2b4c34c6e1e1).
final class D0118IngestionTests: XCTestCase {
    private let seed = "2b4c34c6e1e1"

    func testTerminalStatesExhaustive() {
        XCTAssertTrue(Ingestion.terminalStatesExhaustive())
        for t in Ingestion.allTerminalStates() {
            XCTAssertFalse(NotchReducer.message(for: t).isEmpty)
        }
    }
}
