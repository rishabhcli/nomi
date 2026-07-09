import XCTest
@testable import MnemoOrchestrator

// MARK: - #1 Coverage / escalation

final class CoverageTests: XCTestCase {
    func testWeakWhenEmptyOrLowSimilarity() {
        XCTAssertTrue(Coverage.isWeak(topSimilarity: 0, count: 0))
        XCTAssertTrue(Coverage.isWeak(topSimilarity: 0.3, count: 2))
        XCTAssertFalse(Coverage.isWeak(topSimilarity: 0.72, count: 1))
    }
    func testEscalatedRequestBroadens() {
        let base = SearchRequest(q: "x", searchMode: "memories", rerank: true, threshold: 0.35, limit: 12, container: "c")
        let esc = Coverage.escalate(base)
        XCTAssertEqual(esc.searchMode, "hybrid")
        XCTAssertLessThan(esc.threshold, base.threshold)
        XCTAssertGreaterThan(esc.limit, base.limit)
        XCTAssertEqual(esc.container, "c")
    }
}

// MARK: - #4 Highlight

final class HighlightTests: XCTestCase {
    func testFindsQueryTermRanges() {
        let ranges = Highlight.ranges(query: "build tool", in: "My favorite build tool is Bazel.")
        let text = "My favorite build tool is Bazel."
        let words = ranges.map { r in String(Array(text)[r.lowerBound..<r.upperBound]) }
        XCTAssertTrue(words.contains("build"))
        XCTAssertTrue(words.contains("tool"))
        XCTAssertFalse(words.contains("Bazel"))
    }
    func testCaseInsensitiveAndIgnoresShortStopwords() {
        let ranges = Highlight.ranges(query: "the Aurora", in: "the aurora migration")
        // "the" is too short/stopwordy to highlight; "aurora" matches case-insensitively.
        let text = "the aurora migration"
        let words = ranges.map { String(Array(text)[$0.lowerBound..<$0.upperBound]).lowercased() }
        XCTAssertTrue(words.contains("aurora"))
        XCTAssertFalse(words.contains("the"))
    }
    func testNoMatchesEmpty() {
        XCTAssertTrue(Highlight.ranges(query: "zzz", in: "nothing here").isEmpty)
    }
}

// MARK: - #5 Time window

final class TimeWindowTests: XCTestCase {
    let now = ISO8601DateFormatter().date(from: "2026-07-09T12:00:00Z")!

    func testParsesRelativePhrases() {
        XCTAssertNotNil(TimeWindow.parse(query: "what did I do yesterday?", now: now))
        XCTAssertNotNil(TimeWindow.parse(query: "notes from last week", now: now))
        XCTAssertNotNil(TimeWindow.parse(query: "anything last month", now: now))
        XCTAssertNil(TimeWindow.parse(query: "what is my build tool", now: now))
        // Regression: "may"/"maybe" as modal verbs must not become a May window;
        // "in May" (temporal cue) and other bare months still parse.
        XCTAssertNil(TimeWindow.parse(query: "the release may slip next sprint", now: now))
        XCTAssertNil(TimeWindow.parse(query: "maybe I should refactor", now: now))
        XCTAssertNotNil(TimeWindow.parse(query: "what did I decide in May", now: now))
        XCTAssertNotNil(TimeWindow.parse(query: "notes from March", now: now))
    }
    func testYesterdayIntervalContainsYesterdayNotToday() {
        let w = TimeWindow.parse(query: "yesterday", now: now)!
        let yesterday = ISO8601DateFormatter().date(from: "2026-07-08T15:00:00Z")!
        let today = ISO8601DateFormatter().date(from: "2026-07-09T09:00:00Z")!
        XCTAssertTrue(w.contains(yesterday))
        XCTAssertFalse(w.contains(today))
    }
    func testFilterKeepsInWindowHits() {
        let w = TimeWindow.parse(query: "last week", now: now)!
        let inWin = Retrieved(memory: "recent", similarity: 0.5,
                              source: .init(docId: "a", path: "/a", title: "a", updatedAt: "2026-07-05T12:00:00Z"))
        let outWin = Retrieved(memory: "old", similarity: 0.9,
                               source: .init(docId: "b", path: "/b", title: "b", updatedAt: "2025-01-01T12:00:00Z"))
        let filtered = TimeWindow.filter([inWin, outWin], to: w)
        XCTAssertEqual(filtered.map { $0.source.docId }, ["a"])
    }
    func testFilterFallsBackWhenNothingInWindow() {
        let w = TimeWindow.parse(query: "yesterday", now: now)!
        let old = Retrieved(memory: "old", similarity: 0.9,
                            source: .init(docId: "b", path: "/b", title: "b", updatedAt: "2020-01-01T00:00:00Z"))
        // No hits in-window → return original (don't strand the user with nothing).
        XCTAssertEqual(TimeWindow.filter([old], to: w).count, 1)
    }
}

// MARK: - #6 Export

final class AnswerExportTests: XCTestCase {
    func testMarkdownIncludesQuestionAnswerAndSources() {
        let md = AnswerExport.markdown(
            question: "What is my build tool?",
            answer: "Bazel.",
            sources: [SourceCard(title: "Build notes", path: "/f.md", docId: "d1",
                                 snippet: "favorite build tool is Bazel", relevance: 0.8)])
        XCTAssertTrue(md.contains("What is my build tool?"))
        XCTAssertTrue(md.contains("Bazel."))
        XCTAssertTrue(md.contains("Build notes"))
        XCTAssertTrue(md.contains("/f.md"))
        XCTAssertTrue(md.contains("Mnemo"))   // provenance header
    }
}

// MARK: - #7 Answer cache

final class AnswerCacheTests: XCTestCase {
    func testHitWithinTTLAndVersion() async {
        let cache = AnswerCache(ttl: 100)
        let cards = [SourceCard(title: "t", path: "/p", docId: "d")]
        await cache.store(query: "q", container: "c", corpusVersion: 5,
                          answer: "A", sources: cards, at: 0)
        let hit = await cache.lookup(query: "q", container: "c", corpusVersion: 5, at: 50)
        XCTAssertEqual(hit?.answer, "A")
    }
    func testMissAfterCorpusChanges() async {
        let cache = AnswerCache(ttl: 100)
        await cache.store(query: "q", container: "c", corpusVersion: 5, answer: "A", sources: [], at: 0)
        let hit = await cache.lookup(query: "q", container: "c", corpusVersion: 6, at: 10)
        XCTAssertNil(hit, "a changed corpus invalidates cached answers")
    }
    func testMissAfterTTL() async {
        let cache = AnswerCache(ttl: 100)
        await cache.store(query: "q", container: "c", corpusVersion: 5, answer: "A", sources: [], at: 0)
        let hit = await cache.lookup(query: "q", container: "c", corpusVersion: 5, at: 200)
        XCTAssertNil(hit)
    }
    func testDifferentQueryMisses() async {
        let cache = AnswerCache(ttl: 100)
        await cache.store(query: "q", container: "c", corpusVersion: 5, answer: "A", sources: [], at: 0)
        let hit = await cache.lookup(query: "other", container: "c", corpusVersion: 5, at: 10)
        XCTAssertNil(hit)
    }
}

// MARK: - #10 Action extraction

final class ActionExtractorTests: XCTestCase {
    func testExtractsUrlEmailPhone() {
        let actions = ActionExtractor.extract("Email me at a@b.com or call +1 415 555 7392, see https://x.io/docs")
        let kinds = Set(actions.map(\.kind))
        XCTAssertTrue(kinds.contains(.url))
        XCTAssertTrue(kinds.contains(.email))
        XCTAssertTrue(kinds.contains(.phone))
        XCTAssertTrue(actions.contains { $0.value == "a@b.com" })
        XCTAssertTrue(actions.contains { $0.value.contains("x.io") })
    }
    func testNoActionsInPlainText() {
        XCTAssertTrue(ActionExtractor.extract("Your favorite build tool is Bazel.").isEmpty)
    }
    func testDeduplicates() {
        let actions = ActionExtractor.extract("mail a@b.com and again a@b.com")
        XCTAssertEqual(actions.filter { $0.value == "a@b.com" }.count, 1)
    }
}

// MARK: - #3 Corpus suggestions

final class CorpusSuggesterTests: XCTestCase {
    func testSuggestsAskableQuestionsFromCards() {
        let cards = [SourceCard(title: "Build tooling notes", path: "/b.md", docId: "d1"),
                     SourceCard(title: "Aurora retro", path: "/a.md", docId: "d2")]
        let s = CorpusSuggester.fromCards(cards, max: 3)
        XCTAssertFalse(s.isEmpty)
        XCTAssertTrue(s.contains { $0.contains("Build tooling notes") })
    }
    func testEmptyCardsNoSuggestions() {
        XCTAssertTrue(CorpusSuggester.fromCards([], max: 3).isEmpty)
    }
}
