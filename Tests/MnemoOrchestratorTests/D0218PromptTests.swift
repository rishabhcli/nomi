import XCTest
@testable import MnemoOrchestrator

/// D-0218: Prompt TerminalState exhaustiveness (seed 2009abe5090b).
final class D0218PromptTests: XCTestCase {
    private let seed = "2009abe5090b"

    func testTerminalStatesExhaustive() {
        XCTAssertTrue(Prompt.terminalStatesExhaustive())
        for t in Prompt.allTerminalStates() {
            XCTAssertFalse(NotchReducer.message(for: t).isEmpty)
        }
    }
}
