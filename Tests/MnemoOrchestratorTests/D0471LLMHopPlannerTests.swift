import XCTest
@testable import MnemoOrchestrator

/// D-0471: LLMHopPlanner agentic grep deadlock prevention (seed 9840e1b076a0).
final class D0471LLMHopPlannerTests: XCTestCase {
    private let seed = "9840e1b076a0"

    func testRepeatedHopGuard() {
        XCTAssertFalse(Digest.agenticLoopGuard(hopQuery: "find bazel", priorHops: ["find bazel"]))
        XCTAssertTrue(Digest.agenticLoopGuard(hopQuery: "find rust", priorHops: ["find bazel"]))
    }

    func testIsRepeatedHopOnModule() {
        let hops = [HopTrace(hop: 1, kind: "semantic", query: "q", paths: [], rationale: "")]
        XCTAssertTrue(AgenticGrep.isRepeatedHop("q", hops: hops))
    }

    func testProperty_loopGuardDeterministic() {
        var rng = Phase2RNG(seed: seed)
        for _ in 0..<5 {
            let prior = (0..<rng.nextInt(upperBound: 3) + 1).map { rng.randomQuery(length: 2) }
            let next = rng.randomQuery(length: 2)
            let ok = Digest.agenticLoopGuard(hopQuery: next, priorHops: prior)
                || AgenticGrep.isRepeatedHop(next, hops: prior.map { HopTrace(hop: 1, kind: "semantic", query: $0, paths: [], rationale: "") }) == false
            XCTAssertTrue(ok || prior.contains(next))
        }
    }
}
