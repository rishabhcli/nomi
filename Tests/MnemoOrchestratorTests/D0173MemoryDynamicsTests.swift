import XCTest
@testable import MnemoOrchestrator

/// D-0173: MemoryDynamics profile preamble staleness (seed 6de9d4edd97a).
final class D0173MemoryDynamicsTests: XCTestCase {
    private let seed = "6de9d4edd97a"

    func testFiltersStaleProfilePreamble() {
        let stale = Profile(statics: ["old"], dynamics: [], memories: [])
        XCTAssertTrue(MemoryDynamics.filtersStaleProfilePreamble(stale, active: Set(["old"]) == false))
    }
}
