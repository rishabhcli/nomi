import XCTest
@testable import MnemoOrchestrator

/// D-0244: FollowUp offline refusal paths (seed 490f49196e70).
final class D0244FollowUpTests: XCTestCase {
    private let seed = "490f49196e70"

    func testOfflineRefusalEventsRenderable() {
        var state = NotchState(phase: .input, query: "q", answer: "", sources: [])
        for e in FollowUp.offlineRefusalEvents() where e != .done {
            state = NotchReducer.apply(e, to: state)
        }
        XCTAssertNotNil(state.terminal)
        XCTAssertFalse(NotchReducer.message(for: state.terminal!).isEmpty)
    }
}
