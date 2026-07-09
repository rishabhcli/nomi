import XCTest
@testable import MnemoOrchestrator

// MARK: - #1 Adaptive answer shapes

final class AnswerShapeTests: XCTestCase {
    func testDetectsComparison() {
        XCTAssertEqual(AnswerShape.detect(query: "compare Bazel and CMake", intent: .synthesis), .comparison)
        XCTAssertEqual(AnswerShape.detect(query: "how does A differ from B?", intent: .multihop), .comparison)
        XCTAssertEqual(AnswerShape.detect(query: "Bazel vs CMake", intent: .lookup), .comparison)
    }
    func testDetectsTimeline() {
        XCTAssertEqual(AnswerShape.detect(query: "what's the timeline of the migration?", intent: .synthesis), .timeline)
        XCTAssertEqual(AnswerShape.detect(query: "trace the history of the project", intent: .multihop), .timeline)
    }
    func testDetectsList() {
        XCTAssertEqual(AnswerShape.detect(query: "what are my build tools?", intent: .lookup), .list)
        XCTAssertEqual(AnswerShape.detect(query: "list the blockers", intent: .synthesis), .list)
    }
    func testDetectsDefinition() {
        XCTAssertEqual(AnswerShape.detect(query: "what is Bazel?", intent: .lookup), .definition)
        XCTAssertEqual(AnswerShape.detect(query: "who is my manager?", intent: .lookup), .definition)
    }
    func testDefaultsToSynthesis() {
        XCTAssertEqual(AnswerShape.detect(query: "summarize the incident", intent: .synthesis), .synthesis)
    }
    func testDirectivesAreDistinctAndNonEmpty() {
        let shapes: [AnswerShape] = [.definition, .comparison, .timeline, .list, .synthesis]
        let directives = shapes.map { ResponseStyle.directive(shape: $0, tone: .balanced) }
        XCTAssertEqual(Set(directives).count, shapes.count, "each shape has a distinct directive")
        XCTAssertTrue(directives.allSatisfy { !$0.isEmpty })
        XCTAssertTrue(ResponseStyle.directive(shape: .comparison, tone: .balanced).lowercased().contains("table"))
        XCTAssertTrue(ResponseStyle.directive(shape: .timeline, tone: .balanced).lowercased().contains("chronolog"))
    }
}

// MARK: - #2 Response tone

final class ResponseToneTests: XCTestCase {
    func testToneParsing() {
        XCTAssertEqual(ResponseTone(rawValue: "brief"), .brief)
        XCTAssertEqual(ResponseTone(rawValue: "detailed"), .detailed)
        XCTAssertEqual(ResponseTone(rawValue: "balanced"), .balanced)
        XCTAssertNil(ResponseTone(rawValue: "loud"))
    }
    func testToneShapesDirective() {
        XCTAssertTrue(ResponseStyle.directive(shape: .synthesis, tone: .brief).lowercased().contains("one"))
        XCTAssertTrue(ResponseStyle.directive(shape: .synthesis, tone: .detailed).lowercased().contains("thorough")
            || ResponseStyle.directive(shape: .synthesis, tone: .detailed).lowercased().contains("detail"))
    }
    func testCommandParserToneCommand() {
        XCTAssertEqual(CommandParser.parse("/tone brief"), .command(.tone("brief")))
        XCTAssertEqual(CommandParser.parse("/tone"), .command(.help))
    }
}

// MARK: - #3 Query restatement

final class UnderstandingTests: XCTestCase {
    func testPhraseMentionsSourceCountAndIntent() {
        let p = Understanding.phrase(intent: .multihop, sourceCount: 3)
        XCTAssertTrue(p.contains("3"))
        XCTAssertTrue(p.lowercased().contains("notes") || p.lowercased().contains("sources"))
    }
    func testSingularVsPlural() {
        XCTAssertTrue(Understanding.phrase(intent: .lookup, sourceCount: 1).contains("1 "))
        XCTAssertFalse(Understanding.phrase(intent: .lookup, sourceCount: 1).lowercased().contains("notes"))
    }
    func testZeroSourcesStillReads() {
        XCTAssertFalse(Understanding.phrase(intent: .synthesis, sourceCount: 0).isEmpty)
    }
}

// MARK: - #4 / #10 Confidence

final class ConfidenceTests: XCTestCase {
    func testLevelFromSimilarity() {
        XCTAssertEqual(ConfidenceLevel.forSimilarity(0.85), .high)
        XCTAssertEqual(ConfidenceLevel.forSimilarity(0.55), .medium)
        XCTAssertEqual(ConfidenceLevel.forSimilarity(0.2), .low)
    }
    func testOverallCombinesSimilarityAndSupport() {
        XCTAssertEqual(Confidence.overall(topSimilarity: 0.9, supportedRatio: 1.0), .high)
        XCTAssertEqual(Confidence.overall(topSimilarity: 0.9, supportedRatio: 0.0), .low,
                       "unsupported answer is low confidence regardless of similarity")
        XCTAssertEqual(Confidence.overall(topSimilarity: 0.5, supportedRatio: 0.8), .medium)
    }
    func testFramingLanguage() {
        XCTAssertTrue(Confidence.framing(.high, sourceCount: 3).lowercased().contains("grounded"))
        XCTAssertTrue(Confidence.framing(.low, sourceCount: 1).lowercased().contains("infer")
            || Confidence.framing(.low, sourceCount: 1).lowercased().contains("loose"))
    }
}

// MARK: - #5 Temporal

final class RelativeTimeTests: XCTestCase {
    let now = ISO8601DateFormatter().date(from: "2026-07-09T12:00:00Z")!

    func testJustNowAndMinutes() {
        XCTAssertEqual(RelativeTime.format(iso: "2026-07-09T11:59:30Z", now: now), "just now")
        XCTAssertEqual(RelativeTime.format(iso: "2026-07-09T11:40:00Z", now: now), "20 min ago")
    }
    func testHoursDaysWeeks() {
        XCTAssertEqual(RelativeTime.format(iso: "2026-07-09T09:00:00Z", now: now), "3 hr ago")
        XCTAssertEqual(RelativeTime.format(iso: "2026-07-07T12:00:00Z", now: now), "2 days ago")
        XCTAssertEqual(RelativeTime.format(iso: "2026-06-25T12:00:00Z", now: now), "2 wk ago")
    }
    func testOlderShowsMonthYear() {
        XCTAssertEqual(RelativeTime.format(iso: "2025-03-01T12:00:00Z", now: now), "Mar 2025")
    }
    func testGarbageIsNil() {
        XCTAssertNil(RelativeTime.format(iso: "not-a-date", now: now))
        XCTAssertNil(RelativeTime.format(iso: nil, now: now))
    }
}

// MARK: - #6 Follow-ups

final class FollowUpTests: XCTestCase {
    func testSuggestsFromEvidenceTitles() {
        let ev = [
            Retrieved(memory: "The Aurora migration slipped four weeks.", similarity: 0.8,
                      source: .init(docId: "d1", path: "/retro.md", title: "Retro notes")),
            Retrieved(memory: "The schema freeze delayed the start.", similarity: 0.7,
                      source: .init(docId: "d2", path: "/sync.md", title: "Platform sync")),
        ]
        let s = FollowUpSuggester.suggest(query: "aurora timeline", evidence: ev, max: 3)
        XCTAssertFalse(s.isEmpty)
        XCTAssertLessThanOrEqual(s.count, 3)
        // Suggestions are non-empty, distinct, and not the original query verbatim.
        XCTAssertEqual(Set(s).count, s.count)
        XCTAssertFalse(s.contains("aurora timeline"))
    }
    func testNoEvidenceNoSuggestions() {
        XCTAssertTrue(FollowUpSuggester.suggest(query: "q", evidence: [], max: 3).isEmpty)
    }
}

// MARK: - #8 Cited-span preview

final class SpanPreviewTests: XCTestCase {
    let doc = "We chose PostgreSQL for telemetry. The Aurora migration slipped four weeks because the schema freeze was late. Backups only support MySQL."

    func testExtractsSentenceAroundRange() {
        // Range covering "Aurora migration slipped"
        let start = doc.range(of: "Aurora")!.lowerBound
        let lo = doc.distance(from: doc.startIndex, to: start)
        let preview = SpanPreview.sentence(around: lo..<(lo + 6), in: doc)
        XCTAssertTrue(preview.contains("Aurora migration slipped four weeks"))
        XCTAssertFalse(preview.contains("PostgreSQL"), "only the containing sentence, not neighbors")
    }
    func testClampsOutOfRange() {
        let preview = SpanPreview.sentence(around: 999..<1000, in: doc)
        XCTAssertFalse(preview.isEmpty)
    }
}

// MARK: - Reducer wiring of the new expressive events

final class ExpressiveReducerTests: XCTestCase {
    func testUnderstandingSetsStatusBeforeAnswer() {
        var s = NotchState(phase: .searching, query: "q", answer: "", sources: [])
        s = NotchReducer.apply(.understanding("Reading across 3 notes…"), to: s)
        XCTAssertEqual(s.understanding, "Reading across 3 notes…")
        XCTAssertEqual(s.status, "Reading across 3 notes…")
    }
    func testSuggestionsCarriedAndClearedOnNextQuery() {
        var s = NotchState(phase: .answering, query: "q", answer: "A", sources: [])
        s = NotchReducer.apply(.suggestions(["Why?", "What else?"]), to: s)
        XCTAssertEqual(s.suggestions, ["Why?", "What else?"])
        s = NotchReducer.apply(.routed(intent: "lookup", effort: "medium"), to: s)
        XCTAssertTrue(s.suggestions.isEmpty, "a new query clears stale suggestions")
        XCTAssertTrue(s.understanding.isEmpty)
    }
    func testConfidenceFramingReflectsSourcesAndSupport() {
        var s = NotchState(phase: .answering, query: "q", answer: "One fact here.",
                           sources: [SourceCard(title: "t", path: "/p", docId: "d", relevance: 0.9)])
        // Fully supported (no unsupported flags) + high similarity → grounded.
        XCTAssertEqual(s.overallConfidence, .high)
        XCTAssertTrue(s.confidenceFraming.lowercased().contains("grounded"))
        // Flagging the only sentence unsupported drops confidence to low.
        s.unsupportedSentences = [0]
        XCTAssertEqual(s.overallConfidence, .low)
    }
    func testEmptyAnswerHasNoFraming() {
        let s = NotchState(phase: .searching, query: "q", answer: "", sources: [])
        XCTAssertEqual(s.confidenceFraming, "")
    }
}
