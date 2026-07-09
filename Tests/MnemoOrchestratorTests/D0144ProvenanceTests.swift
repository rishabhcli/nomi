import XCTest
@testable import MnemoOrchestrator

/// D-0144: Provenance offline refusal paths (seed 77aedc6b19e4).
final class D0144ProvenanceTests: XCTestCase {
    private let seed = "77aedc6b19e4"

    func testOfflineRefusalEventsRenderable() {
        var state = NotchState(phase: .input, query: "q", answer: "", sources: [])
        for e in Provenance.offlineRefusalEvents() where e != .done {
            state = NotchReducer.apply(e, to: state)
        }
        XCTAssertNotNil(state.terminal)
        XCTAssertFalse(NotchReducer.message(for: state.terminal!).isEmpty)
    }
}
