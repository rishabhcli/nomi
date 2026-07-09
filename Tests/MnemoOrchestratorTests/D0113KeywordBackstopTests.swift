import XCTest
@testable import MnemoOrchestrator

/// D-0113: KeywordBackstop profile preamble staleness (seed e731cbfe8007).
final class D0113KeywordBackstopTests: XCTestCase {
    private let seed = "e731cbfe8007"

    func testFiltersStaleProfilePreamble() {
        let stale = Profile(statics: ["old"], dynamics: [], memories: [])
        XCTAssertTrue(KeywordBackstop.filtersStaleProfilePreamble(stale, active: Set(["old"]) == false))
    }
}
