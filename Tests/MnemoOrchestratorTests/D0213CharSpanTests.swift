import XCTest
@testable import MnemoOrchestrator

/// D-0213: CharSpan profile preamble staleness (seed a9f0f5bf53f9).
final class D0213CharSpanTests: XCTestCase {
    private let seed = "a9f0f5bf53f9"

    func testFiltersStaleProfilePreamble() {
        let stale = Profile(statics: ["old"], dynamics: [], memories: [])
        XCTAssertTrue(CharSpan.filtersStaleProfilePreamble(stale, active: Set(["old"]) == false))
    }
}
