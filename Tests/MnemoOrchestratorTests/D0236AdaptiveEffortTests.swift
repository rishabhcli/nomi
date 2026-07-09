import XCTest
@testable import MnemoOrchestrator

/// D-0236: AdaptiveEffort subprocess stderr backpressure (seed 9a4fe7e4c9c3).
final class D0236AdaptiveEffortTests: XCTestCase {
    private let seed = "9a4fe7e4c9c3"

    func testDrainsSubprocessStderr() {
        XCTAssertTrue(AdaptiveEffort.drainsSubprocessStderr())
    }
}
