import XCTest
@testable import MnemoOrchestrator

/// D-0309: RouterEscalator memory supersession race conditions (seed 92798fb0971f).
final class D0309RouterEscalatorTests: XCTestCase {
    private let seed = "92798fb0971f"

    func testDreamingSafeRejectsDuplicate() {
        let existing = [Phase2TechniqueSupport.sampleMemory()]
        let text = existing[0].memory
        XCTAssertFalse(RouterEscalator.dreamingSafeSynthesis(text, existing: existing, constituents: ["Bazel"]))
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
            let ok = RouterEscalator.dreamingSafeSynthesis(novel, existing: existing, constituents: ["Bazel"])
            XCTAssertTrue(ok)
        }
    }
}
