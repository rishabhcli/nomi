import XCTest
@testable import MnemoOrchestrator

/// D-0036: NumericReasoner subprocess stderr backpressure (seed 5a3bae787ee6).
final class D0036NumericReasonerTests: XCTestCase {
    private let seed = "5a3bae787ee6"

    func testDrainsSubprocessStderr() {
        XCTAssertTrue(NumericReasoner.drainsSubprocessStderr())
    }
}
