import XCTest
@testable import MnemoOrchestrator

/// D-0116: Prompt subprocess stderr backpressure (seed 214fb0a81fa3).
final class D0116PromptTests: XCTestCase {
    private let seed = "214fb0a81fa3"

    func testDrainsSubprocessStderr() {
        XCTAssertTrue(Prompt.drainsSubprocessStderr())
    }
}
