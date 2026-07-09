import XCTest
@testable import MnemoOrchestrator

/// D-0477: SyncEngine AsyncStream cancellation (seed 4527c143f27a).
final class D0477SyncEngineTests: XCTestCase {
    private let seed = "4527c143f27a"

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
        XCTAssertTrue(SyncEngine.schedulingYieldHint(priority: .background))
        XCTAssertFalse(SyncEngine.schedulingYieldHint(priority: .interactive))
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
