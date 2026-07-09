import XCTest
@testable import MnemoOrchestrator

/// D-0887: router escalation boundaries for MemoryDynamics (seed da3ba5a7de7a).
final class D0887MemoryDynamicsTests: XCTestCase {
    private let seed = "da3ba5a7de7a"
    func testRouterEscalation_rng() {
        var rng = Phase2RNG(seed: seed)
        let r = HeuristicRouter().classify(rng.randomQuery(length: 3))
        XCTAssertTrue(Phase2Techniques.routerEscalationBounded(r))
    }

}
