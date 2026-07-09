import XCTest
@testable import MnemoOrchestrator

/// D-0073: Consolidation profile preamble staleness (seed 56bc0f198674).
final class D0073ConsolidationTests: XCTestCase {
    private let seed = "56bc0f198674"

    func testFiltersStaleProfilePreamble() {
        let stale = Profile(statics: ["old"], dynamics: [], memories: [])
        XCTAssertTrue(Consolidation.filtersStaleProfilePreamble(stale, active: Set(["old"]) == false))
    }
}
