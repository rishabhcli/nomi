import XCTest
@testable import MnemoOrchestrator

/// Regressions for two correctness bugs found during backend testing (2026-07-09):
/// the egress guard's spoofable "127." prefix check, and the citation stripper
/// deleting real parenthetical claim content.
final class EgressHostAndCitationTests: XCTestCase {
    func testGenuineLoopbackAccepted() {
        XCTAssertTrue(EgressGuard.isLoopbackHost("127.0.0.1"))
        XCTAssertTrue(EgressGuard.isLoopbackHost("127.5.6.7"))   // all of 127/8
        XCTAssertTrue(EgressGuard.isLoopbackHost("localhost"))
        XCTAssertTrue(EgressGuard.isLoopbackHost("::1"))
        XCTAssertTrue(EgressGuard.isLoopbackHost("[::1]"))
    }

    func testSpoofedLoopbackHostsAreRejected() {
        XCTAssertFalse(EgressGuard.isLoopbackHost("127.0.0.1.evil.com"))
        XCTAssertFalse(EgressGuard.isLoopbackHost("127.attacker.net"))
        XCTAssertFalse(EgressGuard.isLoopbackHost("127notanip.example.com"))
        XCTAssertFalse(EgressGuard.isLoopbackHost("128.0.0.1"))
        XCTAssertFalse(EgressGuard.isLoopbackHost("api.supermemory.ai"))
    }

    func testStripCitationsKeepsParentheticalClaimContent() {
        XCTAssertTrue(Verification.stripCitations("Revenue grew (to $2M in Q3) [Report].").contains("2M"))
        XCTAssertTrue(Verification.stripCitations("The reduction was (approximately 50%").contains("50"))
    }

    func testStripCitationsStillRemovesRealCitationMarkup() {
        XCTAssertFalse(Verification.stripCitations("Switched to Bazel [Build tooling notes].").contains("Build tooling"))
        XCTAssertFalse(Verification.stripCitations("The answer is 42 【fixture.md】.").contains("fixture.md"))
    }

    // P1: with a distractor date present, the numeric note must not force the
    // global earliest→latest span as the answer — it must list the dated facts
    // and tell the model to pick the correct endpoints.
    func testNumericNoteIsAdvisoryWithDistractorDate() {
        let ev = [
            Retrieved(memory: "The project kicked off on January 5, 2024.", similarity: 0.9,
                      source: SourceLocator(docId: "d1", path: "/a.md", title: "A")),
            Retrieved(memory: "Launch was targeted for June 1, 2024 but slipped to June 22, 2024.",
                      similarity: 0.9, source: SourceLocator(docId: "d2", path: "/b.md", title: "B")),
        ]
        let note = NumericReasoner.durationNote(in: ev) ?? ""
        XCTAssertFalse(note.contains("do not re-derive"),
                       "must not force a possibly-wrong global span")
        XCTAssertTrue(note.contains("Jun 1, 2024"),
                      "must list the individual dated facts so the model can pick endpoints")
        XCTAssertTrue(note.lowercased().contains("actual endpoints")
                        || note.lowercased().contains("correct start and end"))
    }
}

final class A219RegressionTests: XCTestCase {
    func testA219_forgottenFactExcludedAfterForget() {
        let forgotten = MemoryEntry(id: "m219", memory: "Forgotten fact 219.", version: 1,
                                    isLatest: true, isForgotten: true, isStatic: false,
                                    parentMemoryId: nil, rootMemoryId: "m219",
                                    forgetAfter: nil, forgetReason: "user retraction", history: [])
        let active = MemoryEntry(id: "m219b", memory: "Active fact 219.", version: 1,
                                 isLatest: true, isForgotten: false, isStatic: false,
                                 parentMemoryId: nil, rootMemoryId: "m219b",
                                 forgetAfter: nil, forgetReason: nil, history: [])
        let filtered = KeywordBackstop.memoryDynamicsFilter([forgotten, active])
        XCTAssertEqual(filtered.map(\.id), ["m219b"],
                       "re-asked queries must not surface facts retracted via /forget")
    }

    func testA219_ttlExpiredExcluded() {
        let past = ISO8601DateFormatter().string(from: Date().addingTimeInterval(-3600))
        let expired = MemoryEntry(id: "e219", memory: "TTL fact 219.", version: 1,
                                  isLatest: true, isForgotten: false, isStatic: false,
                                  parentMemoryId: nil, rootMemoryId: "e219",
                                  forgetAfter: past, forgetReason: nil, history: [])
        XCTAssertFalse(KeywordBackstop.memoryDynamicsActive(expired),
                       "TTL-expired memories must not appear in answers")
    }
}

final class A132RegressionTests: XCTestCase {
    func testA132_citationIntegrity() {
        let ev = [Retrieved(memory: "User uses Bazel.", similarity: 0.9, source: .init(docId: "d132", path: "/f.md", title: "Notes"))]
        XCTAssertTrue(NotchReducer.citationIntegritySupported("User uses Bazel [Notes].", evidence: ev))
        XCTAssertFalse(NotchReducer.citationIntegritySupported("User uses CMake [Notes].", evidence: ev))
    }
    func testA132_unsupportedAnswerEvent() {
        XCTAssertEqual(NotchReducer.unsupportedAnswerEvents(), [.state(.unsupportedAnswer)])
    }
}

final class A277RegressionTests: XCTestCase {
    func testA277_dreamingDoesNotDuplicateSynthesis() {
        let existing = [MemoryEntry(id: "s277", memory: "Synthesis 277.", version: 1,
                                    isLatest: true, isForgotten: false, isStatic: false,
                                    parentMemoryId: nil, rootMemoryId: "s277",
                                    forgetAfter: nil, forgetReason: nil, history: [])]
        XCTAssertFalse(IngestGate.dreamingSafeSynthesis("Synthesis 277.", existing: existing,
                                                      constituents: ["fact 277"]),
                       "dreaming must not duplicate existing syntheses")
        XCTAssertTrue(IngestGate.dreamingSafeSynthesis("New synthesis 277.", existing: existing,
                                                     constituents: ["fact 277"]),
                      "novel synthesis with constituent grounding is allowed")
    }
}
final class A190RegressionTests: XCTestCase {
    func testA190_ingest() {
        XCTAssertEqual(Consolidator.indexingTerminalState(path:"/a.pdf"),.indexing(path:"/a.pdf"))
        XCTAssertEqual(Consolidator.ingestionSelfHealSafe(orphanIds:["x",""]),["x"])
    }
}
final class A103RegressionTests: XCTestCase { func testA103_x() { XCTAssertFalse(Digest.lifecycleEvents(branch:.routeAmbiguity).isEmpty) } }
final class A161RegressionTests: XCTestCase { func testA161_x() { XCTAssertEqual(Coverage.indexingTerminalState(path:"/p"),.indexing(path:"/p")) } }

final class A248RegressionTests: XCTestCase {
    func testA248_dreamingDoesNotDuplicateSynthesis() {
        let existing = [MemoryEntry(id: "s248", memory: "Synthesis 248.", version: 1,
                                    isLatest: true, isForgotten: false, isStatic: false,
                                    parentMemoryId: nil, rootMemoryId: "s248",
                                    forgetAfter: nil, forgetReason: nil, history: [])]
        XCTAssertFalse(FollowUpSuggester.dreamingSafeSynthesis("Synthesis 248.", existing: existing,
                                                      constituents: ["fact 248"]),
                       "dreaming must not duplicate existing syntheses")
        XCTAssertTrue(FollowUpSuggester.dreamingSafeSynthesis("New synthesis 248.", existing: existing,
                                                     constituents: ["fact 248"]),
                      "novel synthesis with constituent grounding is allowed")
    }
}

/// A-016: IngestIndex maps engine statuses to ItemState terminal transitions.
final class IngestionAuditTests: XCTestCase {
    func testItemStateTerminalFromEngineStatus() {
        XCTAssertEqual(ItemState(engineStatus: "done"), .ready)
        XCTAssertEqual(ItemState(engineStatus: "failed"), .error)
        XCTAssertFalse(ItemState(engineStatus: "extracting").isTerminal)
    }
}

/// A-045: overflow-safe conversation id for Int.min hash.
final class ConversationIdHashTests: XCTestCase {
    func testConversationIdUsesUIntBitPattern() {
        let q = "test query"
        XCTAssertEqual(QueryService.conversationId(for: q), "mnemo-\(UInt(bitPattern: q.hashValue))")
    }
}
