import XCTest
@testable import MnemoOrchestrator

/// D-0184: ScopeClassifier offline refusal paths (seed 7112a08db3e3).
final class D0184ScopeClassifierTests: XCTestCase {
    private let seed = "7112a08db3e3"

    func testOfflineRefusalEventsRenderable() {
        var state = NotchState(phase: .input, query: "q", answer: "", sources: [])
        for e in ScopeClassifier.offlineRefusalEvents() where e != .done {
            state = NotchReducer.apply(e, to: state)
        }
        XCTAssertNotNil(state.terminal)
        XCTAssertFalse(NotchReducer.message(for: state.terminal!).isEmpty)
    }
}
