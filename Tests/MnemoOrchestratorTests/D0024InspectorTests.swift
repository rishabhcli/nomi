import XCTest
@testable import MnemoOrchestrator

/// D-0024: Inspector offline refusal paths (seed af73b7792b6d).
final class D0024InspectorTests: XCTestCase {
    private let seed = "af73b7792b6d"

    func testOfflineRefusalEventsRenderable() {
        var state = NotchState(phase: .input, query: "q", answer: "", sources: [])
        for e in Inspector.offlineRefusalEvents() where e != .done {
            state = NotchReducer.apply(e, to: state)
        }
        XCTAssertNotNil(state.terminal)
        XCTAssertFalse(NotchReducer.message(for: state.terminal!).isEmpty)
    }
}
