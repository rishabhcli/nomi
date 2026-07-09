import XCTest
@testable import MnemoOrchestrator

/// D-0216: LLMHopPlanner subprocess stderr backpressure (seed 402b6a682c30).
final class D0216LLMHopPlannerTests: XCTestCase {
    private let seed = "402b6a682c30"

    func testDrainsSubprocessStderr() {
        XCTAssertTrue(LLMHopPlanner.drainsSubprocessStderr())
    }
}
