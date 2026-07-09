import XCTest
@testable import MnemoOrchestrator

private func shit(_ id: String, _ text: String, _ sim: Double = 0.7, updatedAt: String? = nil) -> Retrieved {
    Retrieved(memory: text, similarity: sim, source: .init(docId: id, path: "/\(id).md", title: id, updatedAt: updatedAt))
}

// MARK: - #2 Numeric / duration reasoning

final class NumericReasonerTests: XCTestCase {
    func testDetectsAggregateQuestions() {
        XCTAssertTrue(NumericReasoner.isNumericQuestion("how many weeks did it slip?"))
        XCTAssertTrue(NumericReasoner.isNumericQuestion("how long was the delay?"))
        XCTAssertTrue(NumericReasoner.isNumericQuestion("what's the total number of blockers?"))
        XCTAssertFalse(NumericReasoner.isNumericQuestion("what is my build tool?"))
    }
    func testComputesDurationBetweenTwoDatesInEvidence() {
        let ev = [shit("a", "Originally scheduled for May 5, 2023."),
                  shit("b", "It actually started on June 2, 2023.")]
        let note = NumericReasoner.durationNote(in: ev)
        XCTAssertNotNil(note)
        // May 5 → Jun 2 is 28 days ≈ 4 weeks.
        XCTAssertTrue(note!.contains("28 days") || note!.contains("4 week"))
    }
    func testNoDurationWhenFewerThanTwoDates() {
        XCTAssertNil(NumericReasoner.durationNote(in: [shit("a", "no dates here")]))
    }
}

// MARK: - #3 Timeline reconstruction

final class TimelineBuilderTests: XCTestCase {
    func testOrdersEventsChronologically() {
        let ev = [shit("c", "Kicked off June 2.", updatedAt: "2026-06-30T00:00:00Z"),
                  shit("a", "Planned for May 5.", updatedAt: "2026-04-01T00:00:00Z"),
                  shit("b", "Slipped to May 19.", updatedAt: "2026-05-15T00:00:00Z")]
        let tl = TimelineBuilder.build(from: ev)
        XCTAssertEqual(tl.map(\.source.docId), ["a", "b", "c"], "earliest source first")
    }
    func testFallsBackWhenNoDates() {
        let ev = [shit("a", "x"), shit("b", "y")]
        XCTAssertEqual(TimelineBuilder.build(from: ev).count, 2)
    }
}

// MARK: - #4 Entity knowledge panel

final class EntityPanelTests: XCTestCase {
    func testAggregatesFactsMentioningEntity() {
        let ev = [shit("a", "The Aurora migration slipped four weeks."),
                  shit("b", "Aurora used PostgreSQL."),
                  shit("c", "Unrelated note about coffee.")]
        let panel = EntityPanel.build(entity: "Aurora", from: ev)
        XCTAssertEqual(panel.entity, "Aurora")
        XCTAssertEqual(panel.facts.count, 2)
        XCTAssertTrue(panel.facts.allSatisfy { $0.lowercased().contains("aurora") })
    }
    func testEmptyWhenNoMentions() {
        XCTAssertTrue(EntityPanel.build(entity: "Nonexistent", from: [shit("a", "x")]).facts.isEmpty)
    }
}

// MARK: - #5 Proactive digest

final class DigestTests: XCTestCase {
    func testSummarizesCorpusState() {
        let d = Digest.build(readyCount: 12, processingCount: 2, failedCount: 1,
                             newSinceLast: 3, conflictsResolved: 1)
        XCTAssertTrue(d.contains("3"))       // new
        XCTAssertTrue(d.lowercased().contains("indexing") || d.contains("2"))
    }
    func testQuietWhenNothingNotable() {
        XCTAssertEqual(Digest.build(readyCount: 10, processingCount: 0, failedCount: 0,
                                    newSinceLast: 0, conflictsResolved: 0), "")
    }
}

// MARK: - #7 Provenance

final class ProvenanceTests: XCTestCase {
    func testMapsSupportedSentencesToSources() {
        let verdicts = [
            SentenceVerdict(index: 0, text: "Bazel is the build tool.", supported: true,
                            bestSource: .init(docId: "d1", path: "/f.md", title: "Build notes")),
            SentenceVerdict(index: 1, text: "It was adopted in March.", supported: false, bestSource: nil),
        ]
        let text = Provenance.explain(verdicts)
        XCTAssertTrue(text.contains("Build notes"))
        XCTAssertTrue(text.lowercased().contains("unsupported") || text.contains("⚠"))
    }
    func testEmptyVerdicts() {
        XCTAssertFalse(Provenance.explain([]).isEmpty)
    }
    func testFromAnswerMapsCitationMarkersToCards() {
        let cards = [SourceCard(title: "Notes A", path: "/a.md", docId: "a", snippet: "", relevance: 0.9, updatedAt: nil),
                     SourceCard(title: "Notes B", path: "/b.md", docId: "b", snippet: "", relevance: 0.8, updatedAt: nil)]
        let verdicts = Provenance.fromAnswer("Bazel is the tool [2]. Unproven claim.",
                                             unsupported: [1], sources: cards)
        XCTAssertEqual(verdicts.count, 2)
        XCTAssertEqual(verdicts[0].bestSource?.title, "Notes B", "[2] maps to the second card")
        XCTAssertTrue(verdicts[0].supported)
        XCTAssertFalse(verdicts[1].supported)
    }
}

// MARK: - #8 Confidence report

final class ConfidenceReportTests: XCTestCase {
    func testDetectsMetaQuestion() {
        XCTAssertTrue(ConfidenceReport.isMetaQuestion("how confident are you?"))
        XCTAssertTrue(ConfidenceReport.isMetaQuestion("how sure are you about that"))
        XCTAssertFalse(ConfidenceReport.isMetaQuestion("what is my build tool"))
    }
    func testReportReflectsLevel() {
        XCTAssertTrue(ConfidenceReport.report(.high, sourceCount: 3).lowercased().contains("confident"))
        XCTAssertTrue(ConfidenceReport.report(.low, sourceCount: 0).lowercased().contains("not"))
    }
}

// MARK: - #9 Preferences

final class PreferencesTests: XCTestCase {
    func testSurfacesMostReferencedFacts() {
        let mems = [MemoryEntry(id: "m1", memory: "Prefers Bazel.", version: 1, isLatest: true, isForgotten: false,
                                isStatic: true, parentMemoryId: nil, rootMemoryId: "m1", forgetAfter: nil,
                                forgetReason: nil, history: []),
                    MemoryEntry(id: "m2", memory: "Uses Neovim.", version: 1, isLatest: true, isForgotten: false,
                                isStatic: false, parentMemoryId: nil, rootMemoryId: "m2", forgetAfter: nil,
                                forgetReason: nil, history: [])]
        let summary = Preferences.summary(memories: mems, strength: ["m2": 10, "m1": 1])
        XCTAssertTrue(summary.contains("Neovim"), "the most-used fact leads")
        XCTAssertTrue(summary.contains("Bazel"), "static identity facts are included")
    }
    func testEmpty() {
        XCTAssertFalse(Preferences.summary(memories: [], strength: [:]).isEmpty)
    }
}

// MARK: - #10 Reconciliation

final class ReconciliationTests: XCTestCase {
    func testReconcilesConflictWithRecency() {
        let ev = [shit("a", "I live in New York City.", updatedAt: "2024-01-01T00:00:00Z"),
                  shit("b", "I live in San Francisco.", updatedAt: "2026-01-01T00:00:00Z")]
        let note = Reconciliation.synthesize(ev)
        XCTAssertNotNil(note)
        XCTAssertTrue(note!.contains("San Francisco"))
    }
    func testNilWhenNoConflict() {
        XCTAssertNil(Reconciliation.synthesize([shit("a", "I use Bazel."), shit("b", "I like coffee.")]))
    }
}
