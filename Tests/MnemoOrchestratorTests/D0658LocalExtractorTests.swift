import XCTest
@testable import MnemoOrchestrator

/// D-0658: TerminalState exhaustiveness for LocalExtractor (seed 6f96e48c75ff).
final class D0658LocalExtractorTests: XCTestCase {
    private let seed = "6f96e48c75ff"

    func testTerminal_exhaustive() {
        XCTAssertTrue(LocalExtractor.terminalStatesExhaustive())
    }

    func testTerminal_allRender() {
        for t in LocalExtractor.allTerminalStates() {
            XCTAssertFalse(NotchReducer.message(for: t).isEmpty)
        }
    }

    func testTerminal_phase2Renderable() {
        XCTAssertTrue(Phase2Techniques.allTerminalStatesRenderable())
    }
}
