import XCTest
@testable import MnemoOrchestrator

/// D-0104: Router offline refusal paths (seed 2a26baad0835).
final class D0104RouterTests: XCTestCase {
    private let seed = "2a26baad0835"

    func testOfflineRefusalEventsRenderable() {
        var state = NotchState(phase: .input, query: "q", answer: "", sources: [])
        for e in Router.offlineRefusalEvents() where e != .done {
            state = NotchReducer.apply(e, to: state)
        }
        XCTAssertNotNil(state.terminal)
        XCTAssertFalse(NotchReducer.message(for: state.terminal!).isEmpty)
    }
}
