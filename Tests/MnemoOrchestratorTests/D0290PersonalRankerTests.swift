import XCTest
@testable import MnemoOrchestrator

/// D-0290: PersonalRanker ingest gate timing proofs (seed 5ea06e148e9f).
final class D0290PersonalRankerTests: XCTestCase {
    private let seed = "5ea06e148e9f"

    func testSchedulingYieldsForBackground() {
        XCTAssertTrue(PersonalRanker.schedulingYieldHint(priority: .background))
    }

    func testAgenticGrepYieldsUnderCap() async throws {
        let surface = FakeGrepSurface(semanticHits: ["q": [GrepHit(path: "/a.md", lineStart: 1, lineEnd: 1, snippet: "x")]],
                                      literalHits: [:])
        let planner = ScriptedPlanner([.semantic("next", rationale: "hop")])
        let r = try await AgenticGrep(surface: surface, planner: planner, maxHops: 2).run("q", scope: nil)
        XCTAssertLessThanOrEqual(r.hops.count, 2)
    }

    func testProperty_gateTimingBounded() async throws {
        var rng = Phase2RNG(seed: seed)
        let max = 1 + rng.nextInt(upperBound: 4)
        let surface = FakeGrepSurface(semanticHits: ["q": [GrepHit(path: "/a.md", lineStart: 1, lineEnd: 1, snippet: "x")]],
                                      literalHits: [:])
        let planner = ScriptedPlanner(Array(repeating: .semantic("hop", rationale: "x"), count: 30))
        let r = try await AgenticGrep(surface: surface, planner: planner, maxHops: max).run("q", scope: nil)
        XCTAssertLessThanOrEqual(r.hops.count, max)
    }
}
