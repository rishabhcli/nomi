import XCTest
@testable import MnemoOrchestrator

/// D-0872: numeric synthesis distractor immunity for EngineClient (seed 47ccbff5c1f4).
final class D0872EngineClientTests: XCTestCase {
    private let seed = "47ccbff5c1f4"
    func testNumericDistractorImmunity_rng() {
        var rng = Phase2RNG(seed: seed)
        let evidence = [Retrieved(memory: "count is 42 items", similarity: 0.9, source: .init(docId: "d", path: "/a.md", title: "a"))]
        let claim = rng.randomQuery(length: 3)
        XCTAssertTrue(Phase2Techniques.immuneToNumericDistractor(claim: claim, evidence: evidence, distractor: "99"))
        XCTAssertTrue(NumericReasoner.isNumericQuestion("how many items?"))
    }

}
