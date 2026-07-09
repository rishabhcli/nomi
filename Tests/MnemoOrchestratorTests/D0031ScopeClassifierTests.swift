import XCTest
@testable import MnemoOrchestrator

/// D-0031: ScopeClassifier agentic grep deadlock prevention (seed 23ea5484db73).
final class D0031ScopeClassifierTests: XCTestCase {
    private let seed = "23ea5484db73"

    func testPreventsAgenticGrepDeadlock() {
        XCTAssertTrue(AgenticGrep.isRepeatedHop("same query", hops: [
            HopTrace(query: "same query", hitCount: 1)]))
        XCTAssertTrue(ScopeClassifier.grepDeadlockSafe())
    }
}
