import XCTest
@testable import MnemoOrchestrator

final class HopPlannerParseTests: XCTestCase {
    func testParsesSemanticDecision() {
        let d = LLMHopPlanner.parse(#"{"action":"semantic","query":"ops backup constraint","rationale":"find the other side"}"#)
        XCTAssertEqual(d, .semantic("ops backup constraint", rationale: "find the other side"))
    }

    func testParsesLiteralAndStop() {
        XCTAssertEqual(LLMHopPlanner.parse(#"{"action":"literal","query":"ERR-4711","rationale":"exact token"}"#),
                       .literal("ERR-4711", rationale: "exact token"))
        XCTAssertEqual(LLMHopPlanner.parse(#"{"action":"stop","rationale":"covered"}"#),
                       .stop(rationale: "covered"))
    }

    func testExtractsJSONEmbeddedInProse() {
        let d = LLMHopPlanner.parse("Sure! Here's my decision:\n```json\n{\"action\":\"stop\",\"rationale\":\"done\"}\n```")
        XCTAssertEqual(d, .stop(rationale: "done"))
    }

    func testGarbageFallsBackToStop() {
        XCTAssertEqual(LLMHopPlanner.parse("I think we should keep looking around"),
                       .stop(rationale: "planner output unparseable"))
    }

    func testPlannerUsesGeneratorOutput() async {
        let gen = FakeGenerator(tokens: [#"{"action":"semantic","query":"timeline note C","rationale":"third doc missing"}"#])
        let planner = LLMHopPlanner(generator: gen)
        let d = await planner.nextHop(question: "reconcile the timeline", evidence: [], hops: [])
        XCTAssertEqual(d, .semantic("timeline note C", rationale: "third doc missing"))
    }
}
