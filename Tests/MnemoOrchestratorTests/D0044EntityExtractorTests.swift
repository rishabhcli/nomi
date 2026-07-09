import XCTest
@testable import MnemoOrchestrator

/// D-0044: EntityExtractor offline refusal paths (seed f97d5e32bcc7).
final class D0044EntityExtractorTests: XCTestCase {
    private let seed = "f97d5e32bcc7"

    func testOfflineRefusalEventsRenderable() {
        var state = NotchState(phase: .input, query: "q", answer: "", sources: [])
        for e in EntityExtractor.offlineRefusalEvents() where e != .done {
            state = NotchReducer.apply(e, to: state)
        }
        XCTAssertNotNil(state.terminal)
        XCTAssertFalse(NotchReducer.message(for: state.terminal!).isEmpty)
    }
}
