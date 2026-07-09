import XCTest
@testable import MnemoOrchestrator

/// D-0231: WorkScheduler agentic grep deadlock prevention (seed cc1b45b6f73c).
final class D0231WorkSchedulerTests: XCTestCase {
    private let seed = "cc1b45b6f73c"

    func testPreventsAgenticGrepDeadlock() {
        XCTAssertTrue(AgenticGrep.isRepeatedHop("same query", hops: [
            HopTrace(query: "same query", hitCount: 1)]))
        XCTAssertTrue(WorkScheduler.grepDeadlockSafe())
    }
}
