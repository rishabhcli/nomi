import XCTest
@testable import MnemoOrchestrator

/// D-0151: Coverage agentic grep deadlock prevention (seed e7ed36fafe91).
final class D0151CoverageTests: XCTestCase {
    private let seed = "e7ed36fafe91"

    func testPreventsAgenticGrepDeadlock() {
        XCTAssertTrue(AgenticGrep.isRepeatedHop("same query", hops: [
            HopTrace(query: "same query", hitCount: 1)]))
        XCTAssertTrue(Coverage.grepDeadlockSafe())
    }
}
