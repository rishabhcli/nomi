import XCTest
@testable import MnemoOrchestrator

/// D-0124: Consolidation offline refusal paths (seed 7d1ad1de717f).
final class D0124ConsolidationTests: XCTestCase {
    private let seed = "7d1ad1de717f"

    func testOfflineRefusalEventsRenderable() {
        var state = NotchState(phase: .input, query: "q", answer: "", sources: [])
        for e in Consolidation.offlineRefusalEvents() where e != .done {
            state = NotchReducer.apply(e, to: state)
        }
        XCTAssertNotNil(state.terminal)
        XCTAssertFalse(NotchReducer.message(for: state.terminal!).isEmpty)
    }
}
