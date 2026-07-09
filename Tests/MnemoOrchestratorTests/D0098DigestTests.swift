import XCTest
@testable import MnemoOrchestrator

/// D-0098: Digest TerminalState exhaustiveness (seed a7813c2b9d1a).
final class D0098DigestTests: XCTestCase {
    private let seed = "a7813c2b9d1a"

    func testTerminalStatesExhaustive() {
        XCTAssertTrue(Digest.terminalStatesExhaustive())
        for t in Digest.allTerminalStates() {
            XCTAssertFalse(NotchReducer.message(for: t).isEmpty)
        }
    }
}
