import XCTest
@testable import MnemoOrchestrator

/// D-0678: TerminalState exhaustiveness for OllamaClient (seed df349b51f7ea).
final class D0678OllamaClientTests: XCTestCase {
    private let seed = "df349b51f7ea"

    func testTerminal_exhaustive() {
        XCTAssertTrue(OllamaClient.terminalStatesExhaustive())
    }

    func testTerminal_allRender() {
        for t in OllamaClient.allTerminalStates() {
            XCTAssertFalse(NotchReducer.message(for: t).isEmpty)
        }
    }

    func testTerminal_phase2Renderable() {
        XCTAssertTrue(Phase2Techniques.allTerminalStatesRenderable())
    }
}
