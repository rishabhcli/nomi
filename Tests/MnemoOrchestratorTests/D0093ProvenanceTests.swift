import XCTest
@testable import MnemoOrchestrator

/// D-0093: Provenance profile preamble staleness (seed 1c56208b8f7c).
final class D0093ProvenanceTests: XCTestCase {
    private let seed = "1c56208b8f7c"

    func testFiltersStaleProfilePreamble() {
        let stale = Profile(statics: ["old"], dynamics: [], memories: [])
        XCTAssertTrue(Provenance.filtersStaleProfilePreamble(stale, active: Set(["old"]) == false))
    }
}
