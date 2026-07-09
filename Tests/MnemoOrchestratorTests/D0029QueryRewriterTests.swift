import XCTest
@testable import MnemoOrchestrator

/// D-0029: QueryRewriter memory supersession race conditions (seed c03cdc35f196).
final class D0029QueryRewriterTests: XCTestCase {
    private let seed = "c03cdc35f196"

    func testSupersessionRaceSafe() {
        let k1 = QueryRewriter.supersessionKey(id: "a", version: 1)
        let k2 = QueryRewriter.supersessionKey(id: "a", version: 2)
        XCTAssertNotEqual(k1, k2)
        XCTAssertTrue(QueryRewriter.supersessionRaceSafe())
    }
}
