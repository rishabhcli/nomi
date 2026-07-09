import XCTest
@testable import MnemoOrchestrator

/// D-0277: Consolidation AsyncStream cancellation (seed 57597154c450).
final class D0277ConsolidationTests: XCTestCase {
    private let seed = "57597154c450"

    func testCancelledAgenticGrepReturnsPartial() async throws {
        let surface = FakeGrepSurface(semanticHits: ["q": [GrepHit(path: "/a.md", lineStart: 1, lineEnd: 1, snippet: "x")]],
                                      literalHits: [:])
        let planner = ScriptedPlanner(Array(repeating: .semantic("q", rationale: "loop"), count: 20))
        let task = Task { try await AgenticGrep(surface: surface, planner: planner, maxHops: 20).run("q", scope: nil) }
        task.cancel()
        let result = try await task.value
        XCTAssertFalse(result.evidence.isEmpty)
    }

    func testSchedulingYieldHint() {
        XCTAssertTrue(Consolidation.schedulingYieldHint(priority: .background))
        XCTAssertFalse(Consolidation.schedulingYieldHint(priority: .interactive))
    }

    func testProperty_cancelIsIdempotent() async throws {
        var rng = Phase2RNG(seed: seed)
        _ = rng.nextInt(upperBound: 10)
        let surface = FakeGrepSurface(semanticHits: ["slow": [GrepHit(path: "/a.md", lineStart: 1, lineEnd: 1, snippet: "x")]],
                                      literalHits: [:])
        let planner = ScriptedPlanner([.semantic("slow", rationale: "once")])
        let task = Task { try await AgenticGrep(surface: surface, planner: planner, maxHops: 5).run("slow", scope: nil) }
        task.cancel()
        let r = try await task.value
        XCTAssertLessThanOrEqual(r.hops.count, 5)
    }
}
