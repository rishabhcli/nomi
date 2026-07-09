import XCTest
@testable import MnemoOrchestrator

/// D-0233: QueryRewriter profile preamble staleness (seed ee746f7dc73b).
final class D0233QueryRewriterTests: XCTestCase {
    private let seed = "ee746f7dc73b"

    func testFiltersStaleProfilePreamble() {
        let stale = Profile(statics: ["old"], dynamics: [], memories: [])
        XCTAssertTrue(QueryRewriter.filtersStaleProfilePreamble(stale, active: Set(["old"]) == false))
    }
}
