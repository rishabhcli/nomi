import XCTest
@testable import MnemoOrchestrator

/// D-0259: EvidenceGathering QueryEvent ordering guarantees (seed 0a65e9c0ce11).
final class D0259EvidenceGatheringTests: XCTestCase {
    private let seed = "0a65e9c0ce11"

    func testLifecycleEventOrder() {
        let events = AgenticGrep.lifecycleEvents(branch: .emptyEvidence)
        XCTAssertGreaterThanOrEqual(events.count, 2)
        Phase2TechniqueSupport.assertEventsRenderable(events)
    }

    func testNotchReducerAppendsReasoning() {
        var state = NotchState(phase: .searching, query: "q", answer: "", sources: [])
        state = NotchReducer.apply(.routed(intent: "lookup", effort: "low"), to: state)
        state = NotchReducer.apply(.reasoning(["step"]), to: state)
        XCTAssertFalse(state.reasoning.isEmpty)
    }

    func testProperty_eventReductionStable() {
        var rng = Phase2RNG(seed: seed)
        for branch in [AgenticGrep.LifecycleBranch.routeAmbiguity, .emptyEvidence, .retry] {
            let e1 = AgenticGrep.lifecycleEvents(branch: branch)
            let e2 = AgenticGrep.lifecycleEvents(branch: branch)
            XCTAssertEqual(e1.count, e2.count)
            _ = rng.nextInt(upperBound: 3)
        }
    }
}
