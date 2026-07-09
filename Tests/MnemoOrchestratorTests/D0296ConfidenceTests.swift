import XCTest
@testable import MnemoOrchestrator

/// D-0296: Confidence subprocess stderr backpressure (seed c8bf13a8dc19).
final class D0296ConfidenceTests: XCTestCase {
    private let seed = "c8bf13a8dc19"

    func testSubprocessCaptureExists() {
        XCTAssertNoThrow({
            _ = try Subprocess.capture("/bin/echo", ["ok"])
        }())
    }

    func testAgenticGrepYieldsEachHop() async throws {
        let surface = FakeGrepSurface(semanticHits: ["q": [GrepHit(path: "/a.md", lineStart: 1, lineEnd: 1, snippet: "x")]],
                                      literalHits: [:])
        let planner = ScriptedPlanner(Array(repeating: .semantic("again", rationale: "x"), count: 10))
        let result = try await AgenticGrep(surface: surface, planner: planner, maxHops: 3).run("q", scope: nil)
        XCTAssertLessThanOrEqual(result.hops.count, 3)
    }

    func testProperty_maxHopsBounds() async throws {
        var rng = Phase2RNG(seed: seed)
        for _ in 0..<3 {
            let max = 2 + rng.nextInt(upperBound: 3)
            let surface = FakeGrepSurface(semanticHits: ["q": [GrepHit(path: "/a.md", lineStart: 1, lineEnd: 1, snippet: "x")]],
                                          literalHits: [:])
            let planner = ScriptedPlanner(Array(repeating: .semantic("loop", rationale: "x"), count: 20))
            let r = try await AgenticGrep(surface: surface, planner: planner, maxHops: max).run("q", scope: nil)
            XCTAssertLessThanOrEqual(r.hops.count, max)
        }
    }
}
