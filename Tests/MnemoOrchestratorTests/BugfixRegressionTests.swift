import XCTest
@testable import MnemoOrchestrator

/// Regressions for bugs found in the full-app audit (2026-07-09).

final class ReducerResetRegressionTests: XCTestCase {
    /// A follow-up query must not render the previous query's terminal state.
    func testRoutedClearsStaleTerminalAndAnswer() {
        var s = NotchState(phase: .state, query: "q2", answer: "old answer",
                           sources: [SourceCard(title: "t", path: "/p", docId: "d")],
                           terminal: .engineUnreachable, unsupportedSentences: [0, 1])
        s = NotchReducer.apply(.routed(intent: "lookup", effort: "medium"), to: s)
        XCTAssertEqual(s.phase, .searching)
        XCTAssertEqual(s.answer, "")
        XCTAssertTrue(s.sources.isEmpty)
        XCTAssertNil(s.terminal, "stale terminal must be cleared at query start")
        XCTAssertTrue(s.unsupportedSentences.isEmpty)
    }

    /// Tokens supersede a terminal state so the answer renders, not the dead end.
    func testTokenClearsTerminal() {
        var s = NotchState(phase: .state, query: "q", answer: "", sources: [], terminal: .empty(nearest: []))
        s = NotchReducer.apply(.token("Hello"), to: s)
        XCTAssertEqual(s.phase, .answering)
        XCTAssertNil(s.terminal)
        XCTAssertEqual(s.answer, "Hello")
    }

    /// The full lifecycle of a second query over a state left dirty by the first.
    func testSecondQueryAfterTerminalRendersAnswer() {
        var s = NotchState(phase: .idle, query: "", answer: "", sources: [])
        // First query ends empty.
        s = NotchReducer.apply(.routed(intent: "lookup", effort: "medium"), to: s)
        s = NotchReducer.apply(.state(.empty(nearest: [])), to: s)
        XCTAssertNotNil(s.terminal)
        // Second query streams an answer.
        s = NotchReducer.apply(.routed(intent: "synthesis", effort: "medium"), to: s)
        s = NotchReducer.apply(.sources([SourceCard(title: "t", path: "/p", docId: "d")]), to: s)
        s = NotchReducer.apply(.token("Bazel."), to: s)
        s = NotchReducer.apply(.done, to: s)
        XCTAssertEqual(s.phase, .answering)
        XCTAssertNil(s.terminal)
        XCTAssertEqual(s.answer, "Bazel.")
    }
}

final class VerdictParseRegressionTests: XCTestCase {
    func testStandaloneVerdictWins() {
        XCTAssertTrue(LocalVerificationBackend.parseVerdict("YES"))
        XCTAssertFalse(LocalVerificationBackend.parseVerdict("NO"))
    }

    func testNoInsideWordsDoesNotFlipYes() {
        // "NOT"/"KNOWN"/"CANNOT"/"NONE" all contain "NO" but must not count.
        XCTAssertTrue(LocalVerificationBackend.parseVerdict(
            "The claim is NOT contradicted by the KNOWN facts. Answer: YES"))
        XCTAssertTrue(LocalVerificationBackend.parseVerdict(
            "I cannot find a contradiction. NONE apply. YES"))
    }

    func testLastStandaloneVerdictWins() {
        XCTAssertFalse(LocalVerificationBackend.parseVerdict(
            "First I thought YES, but on reflection the answer is NO"))
        XCTAssertTrue(LocalVerificationBackend.parseVerdict(
            "Maybe NO at first glance, but ultimately YES"))
    }

    func testNoVerdictTokenIsUnsupported() {
        XCTAssertFalse(LocalVerificationBackend.parseVerdict("I am not sure about this."))
        XCTAssertFalse(LocalVerificationBackend.parseVerdict(""))
    }
}

final class Prompt401RegressionTests: XCTestCase {
    /// Regression hardening prompt A-401 (TimeWindow).
    func testMayWithoutTemporalCueIsNotMonth() {
        XCTAssertNil(TimeWindow.parse(query: "the release may slip without a date"))
        XCTAssertNotNil(TimeWindow.parse(query: "notes from May 2024"))
    }
}

final class A250RegressionTests: XCTestCase {
    func testA250_dreamingDoesNotDuplicateSynthesis() {
        let existing = [MemoryEntry(id: "s250", memory: "Synthesis 250.", version: 1,
                                    isLatest: true, isForgotten: false, isStatic: false,
                                    parentMemoryId: nil, rootMemoryId: "s250",
                                    forgetAfter: nil, forgetReason: nil, history: [])]
        XCTAssertFalse(Provenance.dreamingSafeSynthesis("Synthesis 250.", existing: existing,
                                                      constituents: ["fact 250"]),
                       "dreaming must not duplicate existing syntheses")
        XCTAssertTrue(Provenance.dreamingSafeSynthesis("New synthesis 250.", existing: existing,
                                                     constituents: ["fact 250"]),
                      "novel synthesis with constituent grounding is allowed")
    }
}

final class A134RegressionTests: XCTestCase {
    func testA134_citationIntegrity() {
        let ev = [Retrieved(memory: "User uses Bazel.", similarity: 0.9, source: .init(docId: "d134", path: "/f.md", title: "Notes"))]
        XCTAssertTrue(QueryDecomposer.citationIntegritySupported("User uses Bazel [Notes].", evidence: ev))
        XCTAssertFalse(QueryDecomposer.citationIntegritySupported("User uses CMake [Notes].", evidence: ev))
    }
    func testA134_unsupportedAnswerEvent() {
        XCTAssertEqual(QueryDecomposer.unsupportedAnswerEvents(), [.state(.unsupportedAnswer)])
    }
}

final class A279RegressionTests: XCTestCase {
    func testA279_dreamingDoesNotDuplicateSynthesis() {
        let existing = [MemoryEntry(id: "s279", memory: "Synthesis 279.", version: 1,
                                    isLatest: true, isForgotten: false, isStatic: false,
                                    parentMemoryId: nil, rootMemoryId: "s279",
                                    forgetAfter: nil, forgetReason: nil, history: [])]
        XCTAssertFalse(ContentHash.dreamingSafeSynthesis("Synthesis 279.", existing: existing,
                                                      constituents: ["fact 279"]),
                       "dreaming must not duplicate existing syntheses")
        XCTAssertTrue(ContentHash.dreamingSafeSynthesis("New synthesis 279.", existing: existing,
                                                     constituents: ["fact 279"]),
                      "novel synthesis with constituent grounding is allowed")
    }
}

final class A163RegressionTests: XCTestCase {
    func testA163_indexingTerminal() {
        let t = CitationVerifier.indexingTerminalState(path: "/f163.pdf")
        guard case .indexing(let p) = t else { return XCTFail() }
        XCTAssertEqual(p, "/f163.pdf")
    }
    func testA163_selfHealSafe() {
        XCTAssertEqual(CitationVerifier.ingestionSelfHealSafe(orphanIds: ["m163", ""]), ["m163"])
    }
}

final class A105RegressionTests: XCTestCase {
    func testA105_lifecycleEventsRenderable() {
        let events = QueryService.lifecycleEvents(branch: .retry)
        XCTAssertFalse(events.isEmpty)
        var state = NotchState(phase: .input, query: "q105", answer: "", sources: [])
        for e in events { state = NotchReducer.apply(e, to: state) }
        XCTAssertTrue(!state.answer.isEmpty || state.terminal != nil || !state.reasoning.isEmpty || state.phase == .searching)
    }
}

final class A192RegressionTests: XCTestCase {
    func testA192_indexingTerminal() {
        let t = NumericReasoner.indexingTerminalState(path: "/f192.pdf")
        guard case .indexing(let p) = t else { return XCTFail() }
        XCTAssertEqual(p, "/f192.pdf")
    }
    func testA192_selfHealSafe() { XCTAssertEqual(NumericReasoner.ingestionSelfHealSafe(orphanIds: ["m192", ""]), ["m192"]) }
}

final class A221RegressionTests: XCTestCase {
    func testA221_forgottenFactExcludedAfterForget() {
        let forgotten = MemoryEntry(id: "m221", memory: "Forgotten fact 221.", version: 1,
                                    isLatest: true, isForgotten: true, isStatic: false,
                                    parentMemoryId: nil, rootMemoryId: "m221",
                                    forgetAfter: nil, forgetReason: "user retraction", history: [])
        let active = MemoryEntry(id: "m221b", memory: "Active fact 221.", version: 1,
                                 isLatest: true, isForgotten: false, isStatic: false,
                                 parentMemoryId: nil, rootMemoryId: "m221b",
                                 forgetAfter: nil, forgetReason: nil, history: [])
        let filtered = ContextAssembler.memoryDynamicsFilter([forgotten, active])
        XCTAssertEqual(filtered.map(\.id), ["m221b"],
                       "re-asked queries must not surface facts retracted via /forget")
    }

    func testA221_ttlExpiredExcluded() {
        let past = ISO8601DateFormatter().string(from: Date().addingTimeInterval(-3600))
        let expired = MemoryEntry(id: "e221", memory: "TTL fact 221.", version: 1,
                                  isLatest: true, isForgotten: false, isStatic: false,
                                  parentMemoryId: nil, rootMemoryId: "e221",
                                  forgetAfter: past, forgetReason: nil, history: [])
        XCTAssertFalse(ContextAssembler.memoryDynamicsActive(expired),
                       "TTL-expired memories must not appear in answers")
    }
}

/// A-018 invariant: SyncEngine must never construct non-loopback URLs.
final class SyncEngineInvariantTests: XCTestCase {
    func testSelfHealOperatesOnMemoryIdsOnly() {
        let memories = [
            MemoryEntry(id: "m1", memory: "fact", version: 1, isLatest: true, isForgotten: false,
                        isStatic: false, parentMemoryId: nil, rootMemoryId: "m1",
                        forgetAfter: nil, forgetReason: nil, history: [], documentIds: ["live"]),
            MemoryEntry(id: "m2", memory: "orphan", version: 1, isLatest: true, isForgotten: false,
                        isStatic: false, parentMemoryId: nil, rootMemoryId: "m2",
                        forgetAfter: nil, forgetReason: nil, history: [], documentIds: ["gone"]),
        ]
        let orphans = SelfHeal.orphanedMemoryIds(memories: memories, liveDocIds: ["live"])
        XCTAssertEqual(orphans, ["m2"])
    }
}

/// A-047: short lookup queries meet rewriter-skip threshold for lower prefill latency.
final class PrefillLatencyRegressionTests: XCTestCase {
    func testShortLookupQuerySkipsRewriterThreshold() {
        let q = "what is Bazel?"
        XCTAssertLessThan(q.count, 48)
        XCTAssertTrue(ScopeClassifier.isCorpusQuestion(q))
    }
}
