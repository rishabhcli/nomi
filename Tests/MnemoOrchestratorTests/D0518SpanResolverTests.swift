import XCTest
@testable import MnemoOrchestrator

/// D-0518: TerminalState exhaustiveness for SpanResolver (seed 9954c782b779).
final class D0518SpanResolverTests: XCTestCase {
    private let seed = "9954c782b779"

    func testTerminal_exhaustive() {
        XCTAssertTrue(SpanResolver.terminalStatesExhaustive())
    }

    func testTerminal_allRender() {
        for t in SpanResolver.allTerminalStates() {
            XCTAssertFalse(NotchReducer.message(for: t).isEmpty)
        }
    }

    func testTerminal_phase2Renderable() {
        XCTAssertTrue(Phase2Techniques.allTerminalStatesRenderable())
    }
}
