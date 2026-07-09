import XCTest
@testable import MnemoOrchestrator

/// D-0071: MemoryDynamics agentic grep deadlock prevention (seed 14e7c57006b7).
final class D0071MemoryDynamicsTests: XCTestCase {
    private let seed = "14e7c57006b7"

    func testPreventsAgenticGrepDeadlock() {
        XCTAssertTrue(AgenticGrep.isRepeatedHop("same query", hops: [
            HopTrace(query: "same query", hitCount: 1)]))
        XCTAssertTrue(MemoryDynamics.grepDeadlockSafe())
    }
}
