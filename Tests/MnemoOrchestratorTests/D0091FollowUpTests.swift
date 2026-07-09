import XCTest
@testable import MnemoOrchestrator

/// D-0091: FollowUp agentic grep deadlock prevention (seed d78f6a9521d8).
final class D0091FollowUpTests: XCTestCase {
    private let seed = "d78f6a9521d8"

    func testPreventsAgenticGrepDeadlock() {
        XCTAssertTrue(AgenticGrep.isRepeatedHop("same query", hops: [
            HopTrace(query: "same query", hitCount: 1)]))
        XCTAssertTrue(FollowUp.grepDeadlockSafe())
    }
}
