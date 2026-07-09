import XCTest
@testable import MnemoOrchestrator

/// D-0927: router escalation boundaries for CharSpan (seed d725bb89414f).
final class D0927CharSpanTests: XCTestCase {
    private let seed = "d725bb89414f"
    func testRouterEscalation_rng() {
        var rng = Phase2RNG(seed: seed)
        let r = HeuristicRouter().classify(rng.randomQuery(length: 3))
        XCTAssertTrue(Phase2Techniques.routerEscalationBounded(r))
    }

}
