import XCTest
@testable import MnemoOrchestrator

/// D-0193: FollowUp profile preamble staleness (seed 5906a016b346).
final class D0193FollowUpTests: XCTestCase {
    private let seed = "5906a016b346"

    func testFiltersStaleProfilePreamble() {
        let stale = Profile(statics: ["old"], dynamics: [], memories: [])
        XCTAssertTrue(FollowUp.filtersStaleProfilePreamble(stale, active: Set(["old"]) == false))
    }
}
