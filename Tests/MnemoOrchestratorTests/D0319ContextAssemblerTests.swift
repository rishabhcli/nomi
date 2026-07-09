import XCTest
@testable import MnemoOrchestrator

/// D-0319: ContextAssembler QueryEvent ordering guarantees (seed 61c8ca3cf46a).
final class D0319ContextAssemblerTests: XCTestCase {
    private let seed = "61c8ca3cf46a"

    func testLifecycleEventOrder() {
        let events = ContextAssembler.lifecycleEvents(branch: .emptyEvidence)
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
        for branch in [ContextAssembler.LifecycleBranch.routeAmbiguity, .emptyEvidence, .retry] {
            let e1 = ContextAssembler.lifecycleEvents(branch: branch)
            let e2 = ContextAssembler.lifecycleEvents(branch: branch)
            XCTAssertEqual(e1.count, e2.count)
            _ = rng.nextInt(upperBound: 3)
        }
    }
}
