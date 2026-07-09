import XCTest
@testable import MnemoOrchestrator

/// D-0056: EngineClient subprocess stderr backpressure (seed 8514f6040c7b).
final class D0056EngineClientTests: XCTestCase {
    private let seed = "8514f6040c7b"

    func testDrainsSubprocessStderr() {
        XCTAssertTrue(EngineClient.drainsSubprocessStderr())
    }
}
