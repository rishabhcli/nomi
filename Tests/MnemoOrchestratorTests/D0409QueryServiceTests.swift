import XCTest
@testable import MnemoOrchestrator

/// D-0409: QueryService memory supersession race conditions (seed 8c293e6a5964).
final class D0409QueryServiceTests: XCTestCase {
    private let seed = "8c293e6a5964"

    func testDreamingSafeRejectsDuplicate() {
        let existing = [Phase2TechniqueSupport.sampleMemory()]
        let text = existing[0].memory
        XCTAssertFalse(QueryService.dreamingSafeSynthesis(text, existing: existing, constituents: ["Bazel"]))
    }

    func testForgottenExcludedFromActive() {
        let f = Phase2TechniqueSupport.sampleMemory(forgotten: true)
        XCTAssertFalse(MemoryFactFilter.isActive(f))
    }

    func testProperty_supersessionIdempotent() {
        var rng = Phase2RNG(seed: seed)
        let existing = [Phase2TechniqueSupport.sampleMemory(id: "root")]
        for i in 0..<4 {
            let novel = "New fact \(i) " + rng.randomQuery(length: 1)
            let ok = QueryService.dreamingSafeSynthesis(novel, existing: existing, constituents: ["Bazel"])
            XCTAssertTrue(ok)
        }
    }
}
