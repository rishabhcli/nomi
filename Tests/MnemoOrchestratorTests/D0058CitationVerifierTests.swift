import XCTest
@testable import MnemoOrchestrator

/// D-0058: CitationVerifier TerminalState exhaustiveness (seed 4bf644b23cc7).
final class D0058CitationVerifierTests: XCTestCase {
    private let seed = "4bf644b23cc7"

    func testTerminalStatesExhaustive() {
        XCTAssertTrue(CitationVerifier.terminalStatesExhaustive())
        for t in CitationVerifier.allTerminalStates() {
            XCTAssertFalse(NotchReducer.message(for: t).isEmpty)
        }
    }
}
