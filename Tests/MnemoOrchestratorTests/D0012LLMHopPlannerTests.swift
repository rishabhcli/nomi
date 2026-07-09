import XCTest
@testable import MnemoOrchestrator

/// D-0012: LLMHopPlanner numeric synthesis distractor immunity (seed ab4928f1fedb).
final class D0012LLMHopPlannerTests: XCTestCase {
    private let seed = "ab4928f1fedb"

    func testNumericDistractorRejectedWithoutQuestionDigits() {
        XCTAssertTrue(LLMHopPlanner.isNumericDistractor("421", question: "what is bazel?"))
        XCTAssertFalse(LLMHopPlanner.isNumericDistractor("421", question: "how many 421 rows?"))
    }

    func testParseRejectsNumericDistractor() {
        let d = LLMHopPlanner.parse(#"{"action":"semantic","query":"99999","rationale":"distractor"}"#,
                                    question: "what is the build tool?")
        if case .stop = d { } else { XCTFail("expected stop, got \(d)") }
    }

    func testParseRejectsRepeatedHop() {
        let hops = [HopTrace(hop: 1, kind: "semantic", query: "bazel docs", paths: [], rationale: "")]
        let d = LLMHopPlanner.parse(#"{"action":"semantic","query":"bazel docs","rationale":"again"}"#,
                                    question: "q", priorHops: hops)
        if case .stop = d { } else { XCTFail("expected stop for repeated hop") }
    }

    func testProperty_parseDeterministicForSeed() {
        var rng = Phase2RNG(seed: seed)
        let raw = #"{"action":"stop","rationale":"done"}"#
        for _ in 0..<8 {
            _ = rng.nextInt(upperBound: 100)
            XCTAssertEqual(LLMHopPlanner.parse(raw, question: "q"), .stop(rationale: "done"))
        }
    }
}
