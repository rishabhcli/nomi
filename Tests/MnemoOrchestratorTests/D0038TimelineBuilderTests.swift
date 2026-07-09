import XCTest
@testable import MnemoOrchestrator

/// D-0038: TimelineBuilder TerminalState exhaustiveness (seed a641237d20a5).
final class D0038TimelineBuilderTests: XCTestCase {
    private let seed = "a641237d20a5"

    func testTerminalStatesExhaustive() {
        XCTAssertTrue(TimelineBuilder.terminalStatesExhaustive())
        for t in TimelineBuilder.allTerminalStates() {
            XCTAssertFalse(NotchReducer.message(for: t).isEmpty)
        }
    }
}
