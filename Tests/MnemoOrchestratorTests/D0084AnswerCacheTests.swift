import XCTest
@testable import MnemoOrchestrator

/// D-0084: AnswerCache offline refusal paths (seed 7a0384846c69).
final class D0084AnswerCacheTests: XCTestCase {
    private let seed = "7a0384846c69"

    func testOfflineRefusalEventsRenderable() {
        var state = NotchState(phase: .input, query: "q", answer: "", sources: [])
        for e in AnswerCache.offlineRefusalEvents() where e != .done {
            state = NotchReducer.apply(e, to: state)
        }
        XCTAssertNotNil(state.terminal)
        XCTAssertFalse(NotchReducer.message(for: state.terminal!).isEmpty)
    }
}
