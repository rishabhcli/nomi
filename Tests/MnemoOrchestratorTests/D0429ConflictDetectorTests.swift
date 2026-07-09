import XCTest
@testable import MnemoOrchestrator

/// D-0429: ConflictDetector memory supersession race conditions (seed 41e9590c83ac).
final class D0429ConflictDetectorTests: XCTestCase {
    private let seed = "41e9590c83ac"

    func testDreamingSafeRejectsDuplicate() {
        let existing = [Phase2TechniqueSupport.sampleMemory()]
        let text = existing[0].memory
        XCTAssertFalse(AgenticGrep.dreamingSafeSynthesis(text, existing: existing, constituents: ["Bazel"]))
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
            let ok = AgenticGrep.dreamingSafeSynthesis(novel, existing: existing, constituents: ["Bazel"])
            XCTAssertTrue(ok)
        }
    }
}
