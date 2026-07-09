import XCTest
@testable import MnemoOrchestrator

/// D-0133: ScopeClassifier profile preamble staleness (seed f6ec4e1545c7).
final class D0133ScopeClassifierTests: XCTestCase {
    private let seed = "f6ec4e1545c7"

    func testFiltersStaleProfilePreamble() {
        let stale = Profile(statics: ["old"], dynamics: [], memories: [])
        XCTAssertTrue(ScopeClassifier.filtersStaleProfilePreamble(stale, active: Set(["old"]) == false))
    }
}
