import XCTest
@testable import MnemoOrchestrator

/// D-0171: SyncEngine agentic grep deadlock prevention (seed d359405159bd).
final class D0171SyncEngineTests: XCTestCase {
    private let seed = "d359405159bd"

    func testPreventsAgenticGrepDeadlock() {
        XCTAssertTrue(AgenticGrep.isRepeatedHop("same query", hops: [
            HopTrace(query: "same query", hitCount: 1)]))
        XCTAssertTrue(SyncEngine.grepDeadlockSafe())
    }
}
