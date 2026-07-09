import XCTest
@testable import MnemoOrchestrator

/// D-0131: QueryRewriter agentic grep deadlock prevention (seed dd9287926842).
final class D0131QueryRewriterTests: XCTestCase {
    private let seed = "dd9287926842"

    func testPreventsAgenticGrepDeadlock() {
        XCTAssertTrue(AgenticGrep.isRepeatedHop("same query", hops: [
            HopTrace(query: "same query", hitCount: 1)]))
        XCTAssertTrue(QueryRewriter.grepDeadlockSafe())
    }
}
