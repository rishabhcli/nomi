import XCTest
@testable import MnemoOrchestrator

/// D-0204: ActionExtractor offline refusal paths (seed 942e169f4143).
final class D0204ActionExtractorTests: XCTestCase {
    private let seed = "942e169f4143"

    func testOfflineRefusalEventsRenderable() {
        var state = NotchState(phase: .input, query: "q", answer: "", sources: [])
        for e in ActionExtractor.offlineRefusalEvents() where e != .done {
            state = NotchReducer.apply(e, to: state)
        }
        XCTAssertNotNil(state.terminal)
        XCTAssertFalse(NotchReducer.message(for: state.terminal!).isEmpty)
    }
}
