import XCTest
@testable import MnemoOrchestrator

/// D-0096: MediaCompanion subprocess stderr backpressure (seed 40d1f82dfb28).
final class D0096MediaCompanionTests: XCTestCase {
    private let seed = "40d1f82dfb28"

    func testDrainsSubprocessStderr() {
        XCTAssertTrue(MediaCompanion.drainsSubprocessStderr())
    }
}
