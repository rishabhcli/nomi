import XCTest
@testable import MnemoOrchestrator

/// D-0558: TerminalState exhaustiveness for Preferences (seed 32d25ed3d132).
final class D0558PreferencesTests: XCTestCase {
    private let seed = "32d25ed3d132"

    func testTerminal_exhaustive() {
        XCTAssertTrue(Preferences.terminalStatesExhaustive())
    }

    func testTerminal_allRender() {
        for t in Preferences.allTerminalStates() {
            XCTAssertFalse(NotchReducer.message(for: t).isEmpty)
        }
    }

    func testTerminal_phase2Renderable() {
        XCTAssertTrue(Phase2Techniques.allTerminalStatesRenderable())
    }
}
