import XCTest
@testable import MnemoOrchestrator

/// D-0767: router escalation boundaries for Router (seed 058ec000291e).
final class D0767RouterTests: XCTestCase {
    private let seed = "058ec000291e"
    func testRouterEscalation_rng() {
        var rng = Phase2RNG(seed: seed)
        let r = HeuristicRouter().classify(rng.randomQuery(length: 3))
        XCTAssertTrue(Phase2Techniques.routerEscalationBounded(r))
    }

}
