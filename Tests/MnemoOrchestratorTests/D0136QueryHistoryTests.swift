import XCTest
@testable import MnemoOrchestrator

/// D-0136: QueryHistory subprocess stderr backpressure (seed 2d597e195dac).
final class D0136QueryHistoryTests: XCTestCase {
    private let seed = "2d597e195dac"

    func testDrainsSubprocessStderr() {
        XCTAssertTrue(QueryHistory.drainsSubprocessStderr())
    }
}
