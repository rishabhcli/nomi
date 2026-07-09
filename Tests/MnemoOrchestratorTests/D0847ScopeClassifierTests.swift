import XCTest
@testable import MnemoOrchestrator

/// D-0847: router escalation boundaries for ScopeClassifier (seed ef5482ab460a).
final class D0847ScopeClassifierTests: XCTestCase {
    private let seed = "ef5482ab460a"
    func testRouterEscalation_rng() {
        var rng = Phase2RNG(seed: seed)
        let r = HeuristicRouter().classify(rng.randomQuery(length: 3))
        XCTAssertTrue(Phase2Techniques.routerEscalationBounded(r))
    }

    func testClassifyChitChat() {
        let c = ScopeClassifier.classify("hello")
        XCTAssertFalse(c.isCorpusQuestion)
        XCTAssertNotNil(c.reply)
    }
    func testClassifyCorpus() {
        let c = ScopeClassifier.classify("what is in my notes about bazel?")
        XCTAssertTrue(c.isCorpusQuestion)
        XCTAssertNil(c.reply)
    }
}
