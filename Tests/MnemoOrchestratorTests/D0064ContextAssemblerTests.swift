import XCTest
@testable import MnemoOrchestrator

/// D-0064: ContextAssembler offline refusal paths (seed 2344feacf231).
final class D0064ContextAssemblerTests: XCTestCase {
    private let seed = "2344feacf231"

    func testOfflineRefusalEventsRenderable() {
        var state = NotchState(phase: .input, query: "q", answer: "", sources: [])
        for e in ContextAssembler.offlineRefusalEvents() where e != .done {
            state = NotchReducer.apply(e, to: state)
        }
        XCTAssertNotNil(state.terminal)
        XCTAssertFalse(NotchReducer.message(for: state.terminal!).isEmpty)
    }
}
