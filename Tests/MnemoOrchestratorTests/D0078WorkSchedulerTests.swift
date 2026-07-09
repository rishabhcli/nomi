import XCTest
@testable import MnemoOrchestrator

/// D-0078: WorkScheduler TerminalState exhaustiveness (seed 2cd67bf1e70a).
final class D0078WorkSchedulerTests: XCTestCase {
    private let seed = "2cd67bf1e70a"

    func testTerminalStatesExhaustive() {
        XCTAssertTrue(WorkScheduler.terminalStatesExhaustive())
        for t in WorkScheduler.allTerminalStates() {
            XCTAssertFalse(NotchReducer.message(for: t).isEmpty)
        }
    }
}
