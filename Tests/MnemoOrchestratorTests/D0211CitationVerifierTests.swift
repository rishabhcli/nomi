import XCTest
@testable import MnemoOrchestrator

/// D-0211: CitationVerifier agentic grep deadlock prevention (seed 3f61e83f1453).
final class D0211CitationVerifierTests: XCTestCase {
    private let seed = "3f61e83f1453"

    func testPreventsAgenticGrepDeadlock() {
        XCTAssertTrue(AgenticGrep.isRepeatedHop("same query", hops: [
            HopTrace(query: "same query", hitCount: 1)]))
        XCTAssertTrue(CitationVerifier.grepDeadlockSafe())
    }
}
