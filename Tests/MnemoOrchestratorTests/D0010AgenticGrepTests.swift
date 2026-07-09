import XCTest
@testable import MnemoOrchestrator

/// D-0010: AgenticGrep ingest gate timing proofs (seed 73570c437cbb).
final class D0010AgenticGrepTests: XCTestCase {
    private let seed = "73570c437cbb"

    func testRepeatedHopStopsLoop() async throws {
        let surface = FakeGrepSurface(semanticHits: ["q": [GrepHit(path: "/a.md", lineStart: 1, lineEnd: 1, snippet: "x")]],
                                      literalHits: [:])
        let planner = ScriptedPlanner([.semantic("q", rationale: "repeat")])
        let agentic = AgenticGrep(surface: surface, planner: planner, maxHops: 6)
        let result = try await agentic.run("q", scope: nil)
        XCTAssertLessThanOrEqual(result.hops.count, 2)
    }

    func testIsRepeatedHopDetectsPriorQuery() {
        let hops = [HopTrace(hop: 1, kind: "semantic", query: "find bazel", paths: [], rationale: "")]
        XCTAssertTrue(AgenticGrep.isRepeatedHop("find bazel", hops: hops))
        XCTAssertFalse(AgenticGrep.isRepeatedHop("find rust", hops: hops))
    }

    func testCancellationReturnsPartialResult() async throws {
        let surface = FakeGrepSurface(semanticHits: ["slow": [GrepHit(path: "/a.md", lineStart: 1, lineEnd: 1, snippet: "x")]],
                                      literalHits: [:])
        let planner = ScriptedPlanner(Array(repeating: .semantic("slow", rationale: "loop"), count: 20))
        let agentic = AgenticGrep(surface: surface, planner: planner, maxHops: 20)
        let task = Task { try await agentic.run("slow", scope: nil) }
        task.cancel()
        let result = try await task.value
        XCTAssertFalse(result.evidence.isEmpty)
    }

    func testProperty_maxHopsBoundsHops() async throws {
        var rng = Phase2RNG(seed: seed)
        for _ in 0..<5 {
            let max = 2 + rng.nextInt(upperBound: 4)
            let surface = FakeGrepSurface(semanticHits: ["q": [GrepHit(path: "/a.md", lineStart: 1, lineEnd: 1, snippet: "x")]],
                                          literalHits: [:])
            let planner = ScriptedPlanner(Array(repeating: .semantic("again", rationale: "x"), count: 50))
            let result = try await AgenticGrep(surface: surface, planner: planner, maxHops: max).run("q", scope: nil)
            XCTAssertLessThanOrEqual(result.hops.count, max)
        }
    }
}
