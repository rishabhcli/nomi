import XCTest
@testable import MnemoOrchestrator

private func rhit(_ id: String, _ text: String, _ sim: Double, updatedAt: String? = nil) -> Retrieved {
    Retrieved(memory: text, similarity: sim, source: .init(docId: id, path: "/\(id).md", title: id, updatedAt: updatedAt))
}

// MARK: - #6 Adaptive effort

final class AdaptiveEffortTests: XCTestCase {
    let policy = EffortPolicy(routing: "low", extraction: "low", synthesis: "medium", multihop: "high")

    func testMultihopStaysHigh() {
        XCTAssertEqual(AdaptiveEffort.select(policy, intent: .multihop, coverageWeak: false, decomposed: false), "high")
    }
    func testWeakCoverageBumpsSynthesisToHigh() {
        XCTAssertEqual(AdaptiveEffort.select(policy, intent: .synthesis, coverageWeak: true, decomposed: false), "high")
    }
    func testDecompositionBumpsEffort() {
        XCTAssertEqual(AdaptiveEffort.select(policy, intent: .lookup, coverageWeak: false, decomposed: true), "high")
    }
    func testTrivialLookupStaysAtBase() {
        XCTAssertEqual(AdaptiveEffort.select(policy, intent: .lookup, coverageWeak: false, decomposed: false), "medium")
    }
}

// MARK: - #7 Personalized ranking

final class PersonalRankerTests: XCTestCase {
    let now = ISO8601DateFormatter().date(from: "2026-07-09T12:00:00Z")!

    func testStrongUsageLiftsAModeratelySimilarHit() {
        let a = rhit("a", "used a lot", 0.55)
        let b = rhit("b", "slightly better match", 0.62)
        // b is more similar, but a has been retrieved many times → a should win.
        let ranked = PersonalRanker.rank([b, a], strength: ["a": 20, "b": 0], now: now)
        XCTAssertEqual(ranked.first?.source.docId, "a")
    }
    func testRecencyBreaksNearTies() {
        let fresh = rhit("fresh", "x", 0.6, updatedAt: "2026-07-08T12:00:00Z")
        let stale = rhit("stale", "x", 0.6, updatedAt: "2024-01-01T12:00:00Z")
        let ranked = PersonalRanker.rank([stale, fresh], strength: [:], now: now)
        XCTAssertEqual(ranked.first?.source.docId, "fresh")
    }
    func testPureSimilarityDominatesWhenNoSignals() {
        let ranked = PersonalRanker.rank([rhit("a", "x", 0.3), rhit("b", "x", 0.9)], strength: [:], now: now)
        XCTAssertEqual(ranked.first?.source.docId, "b")
    }
}

// MARK: - #5 Conflict detection

final class ConflictDetectorTests: XCTestCase {
    func testDetectsConflictingLocationFacts() {
        let ev = [rhit("a", "I live in New York City.", 0.8, updatedAt: "2024-01-01T00:00:00Z"),
                  rhit("b", "I live in San Francisco.", 0.8, updatedAt: "2026-01-01T00:00:00Z")]
        let conflicts = ConflictDetector.conflicts(in: ev)
        XCTAssertEqual(conflicts.count, 1)
        // The more recent fact is flagged as current.
        XCTAssertTrue(conflicts[0].note.contains("San Francisco"))
        XCTAssertTrue(conflicts[0].note.lowercased().contains("new york"))
    }
    func testNoConflictForUnrelatedFacts() {
        let ev = [rhit("a", "I live in NYC.", 0.8), rhit("b", "I use Bazel.", 0.8)]
        XCTAssertTrue(ConflictDetector.conflicts(in: ev).isEmpty)
    }
}

// MARK: - #8 Entity extraction

final class EntityExtractorTests: XCTestCase {
    func testExtractsCapitalizedEntities() {
        let e = EntityExtractor.entities(in: "The Aurora migration used PostgreSQL and Bazel.")
        XCTAssertTrue(e.contains("Aurora"))
        XCTAssertTrue(e.contains("PostgreSQL"))
        XCTAssertTrue(e.contains("Bazel"))
    }
    func testDropsSentenceInitialAndStopwords() {
        let e = EntityExtractor.entities(in: "The user prefers dark mode.")
        XCTAssertFalse(e.contains("The"))
        XCTAssertFalse(e.contains("user"))
    }
    func testDeduplicatesAndCaps() {
        let e = EntityExtractor.entities(in: "Bazel Bazel Bazel and CMake and Rust and Swift and Metal", max: 3)
        XCTAssertLessThanOrEqual(e.count, 3)
        XCTAssertEqual(Set(e).count, e.count)
    }
}

// MARK: - #9 Out-of-scope / chit-chat

final class ScopeClassifierTests: XCTestCase {
    func testGreetingsAndChitChatAreOutOfScope() {
        XCTAssertFalse(ScopeClassifier.isCorpusQuestion("hi"))
        XCTAssertFalse(ScopeClassifier.isCorpusQuestion("hello there"))
        XCTAssertFalse(ScopeClassifier.isCorpusQuestion("thanks!"))
        XCTAssertFalse(ScopeClassifier.isCorpusQuestion("who are you?"))
        XCTAssertFalse(ScopeClassifier.isCorpusQuestion("what can you do?"))
    }
    func testRealQuestionsAreInScope() {
        XCTAssertTrue(ScopeClassifier.isCorpusQuestion("what is my favorite build tool?"))
        XCTAssertTrue(ScopeClassifier.isCorpusQuestion("reconcile the Aurora timeline"))
    }
    func testReplyForChitChatIsFriendly() {
        XCTAssertFalse(ScopeClassifier.reply(for: "hi").isEmpty)
        XCTAssertTrue(ScopeClassifier.reply(for: "what can you do?").lowercased().contains("files")
            || ScopeClassifier.reply(for: "what can you do?").lowercased().contains("ask"))
    }
}

// MARK: - #10 Decomposition

final class QueryDecomposerTests: XCTestCase {
    func testSplitsCompoundOnAnd() {
        let parts = QueryDecomposer.split("what is my build tool and when did I adopt it?")
        XCTAssertEqual(parts.count, 2)
        XCTAssertTrue(parts[0].lowercased().contains("build tool"))
        XCTAssertTrue(parts[1].lowercased().contains("adopt"))
    }
    func testSingleQuestionNotSplit() {
        XCTAssertEqual(QueryDecomposer.split("what is my favorite build tool?"), ["what is my favorite build tool?"])
    }
    func testDoesNotSplitShortAndPhrases() {
        // "black and white" shouldn't split into fragments.
        XCTAssertEqual(QueryDecomposer.split("what is black and white?").count, 1)
    }
}

// MARK: - #2 Query rewriting parse

final class QueryRewriteParseTests: XCTestCase {
    func testExtractsRewriteFromModelOutput() {
        XCTAssertEqual(LLMQueryRewriter.parse("Rewritten: Aurora migration start date and slip reasons", original: "when aurora"),
                       "Aurora migration start date and slip reasons")
        XCTAssertEqual(LLMQueryRewriter.parse("\"database backup constraints\"", original: "backups"),
                       "database backup constraints")
    }
    func testFallsBackToOriginalOnGarbage() {
        XCTAssertEqual(LLMQueryRewriter.parse("", original: "orig"), "orig")
        XCTAssertEqual(LLMQueryRewriter.parse("I'm not sure what you mean, could you clarify a lot more please?", original: "orig"), "orig")
    }
}

// MARK: - #4 Router escalation parse

final class RouterEscalationParseTests: XCTestCase {
    func testParsesIntent() {
        XCTAssertEqual(LLMRouterEscalator.parse(#"{"intent":"multihop"}"#), .multihop)
        XCTAssertEqual(LLMRouterEscalator.parse("intent: profile"), .profile)
        XCTAssertEqual(LLMRouterEscalator.parse("lookup"), .lookup)
    }
    func testGarbageFallsBackToSynthesis() {
        XCTAssertEqual(LLMRouterEscalator.parse("no idea"), .synthesis)
    }
}
