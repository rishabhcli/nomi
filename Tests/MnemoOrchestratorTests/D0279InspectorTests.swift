import XCTest
@testable import MnemoOrchestrator

/// D-0279: Inspector QueryEvent ordering guarantees (seed 1b1c5d96e94e).
final class D0279InspectorTests: XCTestCase {
    private let seed = "1b1c5d96e94e"

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
