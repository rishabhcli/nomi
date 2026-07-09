import XCTest
@testable import MnemoOrchestrator

/// D-0053: Router profile preamble staleness (seed 4e32c3b4022c).
final class D0053RouterTests: XCTestCase {
    private let seed = "4e32c3b4022c"

    func testFiltersStaleProfilePreamble() {
        let stale = Profile(statics: ["old"], dynamics: [], memories: [])
        XCTAssertTrue(Router.filtersStaleProfilePreamble(stale, active: Set(["old"]) == false))
    }
}
