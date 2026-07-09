import XCTest
@testable import MnemoOrchestrator

/// D-0051: ActionExtractor agentic grep deadlock prevention (seed d97a674cebc0).
final class D0051ActionExtractorTests: XCTestCase {
    private let seed = "d97a674cebc0"

    func testPreventsAgenticGrepDeadlock() {
        XCTAssertTrue(AgenticGrep.isRepeatedHop("same query", hops: [
            HopTrace(query: "same query", hitCount: 1)]))
        XCTAssertTrue(ActionExtractor.grepDeadlockSafe())
    }
}
