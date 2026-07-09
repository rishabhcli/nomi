import XCTest
@testable import MnemoOrchestrator

/// D-0706: token budget adversarial trim for CommandParser (seed 48dd9ec1773b).
final class D0706CommandParserTests: XCTestCase {
    private let seed = "48dd9ec1773b"

    func testTokenBudget_trimAdversarial() {
        let hits = Phase2TestSupport.sampleEvidence
        let trimmed = CommandParser.trimAdversarial(hits, tokenBudget: 50)
        XCTAssertTrue(CommandParser.tokenBudgetInvariant(trimmed, budget: 50))
    }

    func testTokenBudget_phase2RespectsBudget() {
        XCTAssertTrue(Phase2Techniques.adversarialTrimRespectsBudget(
            preamble: "p", evidence: Phase2TestSupport.sampleEvidence, budget: 4000))
    }

    func testTokenBudget_emptyHitsInvariant() {
        XCTAssertTrue(CommandParser.tokenBudgetInvariant([], budget: 100))
    }

    func testParse_slashCommands() {
        XCTAssertEqual(CommandParser.parse("/help"), .command(.help))
        XCTAssertEqual(CommandParser.parse("plain query"), .query("plain query"))
    }
}
