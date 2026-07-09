import XCTest
@testable import MnemoOrchestrator

/// D-0033: AnswerCache profile preamble staleness (seed 8dece9fb1c89).
final class D0033AnswerCacheTests: XCTestCase {
    private let seed = "8dece9fb1c89"

    func testFiltersStaleProfilePreamble() {
        let stale = Profile(statics: ["old"], dynamics: [], memories: [])
        XCTAssertTrue(AnswerCache.filtersStaleProfilePreamble(stale, active: Set(["old"]) == false))
    }
}
