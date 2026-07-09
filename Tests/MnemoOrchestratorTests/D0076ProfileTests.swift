import XCTest
@testable import MnemoOrchestrator

/// D-0076: Profile subprocess stderr backpressure (seed 4583999e20e7).
final class D0076ProfileTests: XCTestCase {
    private let seed = "4583999e20e7"

    func testDrainsSubprocessStderr() {
        XCTAssertTrue(Profile.drainsSubprocessStderr())
    }
}
