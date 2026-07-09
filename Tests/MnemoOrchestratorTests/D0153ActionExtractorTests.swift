import XCTest
@testable import MnemoOrchestrator

/// D-0153: ActionExtractor profile preamble staleness (seed 10678d195245).
final class D0153ActionExtractorTests: XCTestCase {
    private let seed = "10678d195245"

    func testFiltersStaleProfilePreamble() {
        let stale = Profile(statics: ["old"], dynamics: [], memories: [])
        XCTAssertTrue(ActionExtractor.filtersStaleProfilePreamble(stale, active: Set(["old"]) == false))
    }
}
