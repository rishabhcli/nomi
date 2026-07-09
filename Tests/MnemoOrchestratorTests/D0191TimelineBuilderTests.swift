import XCTest
@testable import MnemoOrchestrator

/// D-0191: TimelineBuilder agentic grep deadlock prevention (seed 6519a9e98efe).
final class D0191TimelineBuilderTests: XCTestCase {
    private let seed = "6519a9e98efe"

    func testPreventsAgenticGrepDeadlock() {
        XCTAssertTrue(AgenticGrep.isRepeatedHop("same query", hops: [
            HopTrace(query: "same query", hitCount: 1)]))
        XCTAssertTrue(TimelineBuilder.grepDeadlockSafe())
    }
}
