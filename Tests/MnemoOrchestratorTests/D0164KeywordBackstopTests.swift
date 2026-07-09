import XCTest
@testable import MnemoOrchestrator

/// D-0164: KeywordBackstop offline refusal paths (seed a69a7864e509).
final class D0164KeywordBackstopTests: XCTestCase {
    private let seed = "a69a7864e509"

    func testOfflineRefusalEventsRenderable() {
        var state = NotchState(phase: .input, query: "q", answer: "", sources: [])
        for e in KeywordBackstop.offlineRefusalEvents() where e != .done {
            state = NotchReducer.apply(e, to: state)
        }
        XCTAssertNotNil(state.terminal)
        XCTAssertFalse(NotchReducer.message(for: state.terminal!).isEmpty)
    }
}
