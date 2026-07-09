import XCTest
@testable import MnemoOrchestrator

/// D-0111: CharSpan agentic grep deadlock prevention (seed c05dbd5ed0f7).
final class D0111CharSpanTests: XCTestCase {
    private let seed = "c05dbd5ed0f7"

    func testPreventsAgenticGrepDeadlock() {
        XCTAssertTrue(AgenticGrep.isRepeatedHop("same query", hops: [
            HopTrace(query: "same query", hitCount: 1)]))
        XCTAssertTrue(CharSpan.grepDeadlockSafe())
    }
}
