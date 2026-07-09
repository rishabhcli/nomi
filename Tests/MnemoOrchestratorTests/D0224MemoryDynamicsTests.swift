import XCTest
@testable import MnemoOrchestrator

/// D-0224: MemoryDynamics offline refusal paths (seed a0233459673a).
final class D0224MemoryDynamicsTests: XCTestCase {
    private let seed = "a0233459673a"

    func testOfflineRefusalEventsRenderable() {
        var state = NotchState(phase: .input, query: "q", answer: "", sources: [])
        for e in MemoryDynamics.offlineRefusalEvents() where e != .done {
            state = NotchReducer.apply(e, to: state)
        }
        XCTAssertNotNil(state.terminal)
        XCTAssertFalse(NotchReducer.message(for: state.terminal!).isEmpty)
    }
}
