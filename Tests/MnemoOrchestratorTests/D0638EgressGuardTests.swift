import XCTest
@testable import MnemoOrchestrator

/// D-0638: TerminalState exhaustiveness for EgressGuard (seed f8cd905ea325).
final class D0638EgressGuardTests: XCTestCase {
    private let seed = "f8cd905ea325"

    func testTerminal_exhaustive() {
        XCTAssertTrue(EgressGuard.terminalStatesExhaustive())
    }

    func testTerminal_allRender() {
        for t in EgressGuard.allTerminalStates() {
            XCTAssertFalse(NotchReducer.message(for: t).isEmpty)
        }
    }

    func testTerminal_phase2Renderable() {
        XCTAssertTrue(Phase2Techniques.allTerminalStatesRenderable())
    }
}
