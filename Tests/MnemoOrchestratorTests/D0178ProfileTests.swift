import XCTest
@testable import MnemoOrchestrator

/// D-0178: Profile TerminalState exhaustiveness (seed 49f4199da0bc).
final class D0178ProfileTests: XCTestCase {
    private let seed = "49f4199da0bc"

    func testTerminalStatesExhaustive() {
        XCTAssertTrue(Profile.terminalStatesExhaustive())
        for t in Profile.allTerminalStates() {
            XCTAssertFalse(NotchReducer.message(for: t).isEmpty)
        }
    }
}
