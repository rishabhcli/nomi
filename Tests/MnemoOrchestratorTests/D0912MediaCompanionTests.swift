import XCTest
@testable import MnemoOrchestrator

/// D-0912: numeric synthesis distractor immunity for MediaCompanion (seed fff740d3a9a6).
final class D0912MediaCompanionTests: XCTestCase {
    private let seed = "fff740d3a9a6"
    func testNumericDistractorImmunity_rng() {
        var rng = Phase2RNG(seed: seed)
        let evidence = [Retrieved(memory: "count is 42 items", similarity: 0.9, source: .init(docId: "d", path: "/a.md", title: "a"))]
        let claim = rng.randomQuery(length: 3)
        XCTAssertTrue(Phase2Techniques.immuneToNumericDistractor(claim: claim, evidence: evidence, distractor: "99"))
        XCTAssertTrue(NumericReasoner.isNumericQuestion("how many items?"))
    }

}
