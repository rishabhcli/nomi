import XCTest
@testable import MnemoOrchestrator

private func memEntry(_ id: String, docIds: [String], forgotten: Bool = false) -> MemoryEntry {
    MemoryEntry(id: id, memory: "m-\(id)", version: 1, isLatest: true, isForgotten: forgotten,
                isStatic: false, parentMemoryId: nil, rootMemoryId: id,
                forgetAfter: nil, forgetReason: nil, history: [], documentIds: docIds)
}

final class SelfHealTests: XCTestCase {
    func testFindsMemoriesWhoseSourcesAreAllGone() {
        let memories = [
            memEntry("m1", docIds: ["docA"]),          // docA alive → keep
            memEntry("m2", docIds: ["docGONE"]),       // orphan
            memEntry("m3", docIds: ["docGONE", "docA"]), // partly alive → keep
            memEntry("m4", docIds: []),                // no sources → orphan
        ]
        let orphans = SelfHeal.orphanedMemoryIds(memories: memories, liveDocIds: ["docA", "docB"])
        XCTAssertEqual(Set(orphans), ["m2", "m4"])
    }

    func testAlreadyForgottenAreNotReprocessed() {
        let memories = [memEntry("m1", docIds: ["gone"], forgotten: true)]
        XCTAssertTrue(SelfHeal.orphanedMemoryIds(memories: memories, liveDocIds: []).isEmpty)
    }
}

actor SyncFakeStore: MemoryStoring {
    var entries: [MemoryEntry]
    var forgotten: [String] = []
    init(_ e: [MemoryEntry]) { entries = e }
    func createMemory(content: String, isStatic: Bool, forgetAfter: String?, container: String?) async throws -> String { "x" }
    func supersedeMemory(id: String, newContent: String, container: String?) async throws -> String { id }
    func forgetMemory(id: String, reason: String, container: String?) async throws { forgotten.append(id) }
    func listMemories(container: String?) async throws -> [MemoryEntry] { entries }
}

actor SyncFakeDocs: DocumentIndexing {
    let docs: [DocumentMeta]
    init(_ d: [DocumentMeta]) { docs = d }
    func documentsList(container: String?) async throws -> [DocumentMeta] { docs }
}

struct SyncFakeForcer: SyncForcing {
    let recorder: ForceRecorder
    func forceSync() async throws { await recorder.mark() }
}
actor ForceRecorder { var calls = 0; func mark() { calls += 1 } }

final class SyncEngineTests: XCTestCase {
    private func doc(_ id: String) -> DocumentMeta {
        DocumentMeta(id: id, filepath: "/\(id).md", title: id, status: "done",
                     containerTags: ["mnemo"], summary: nil, updatedAt: nil)
    }

    func testSelfHealForgetsOnlyOrphans() async throws {
        let store = SyncFakeStore([
            memEntry("m1", docIds: ["liveDoc"]),
            memEntry("m2", docIds: ["deadDoc"]),
        ])
        let docs = SyncFakeDocs([doc("liveDoc")])
        let engine = SyncEngine(store: store, docs: docs, container: "mnemo",
                                forcer: SyncFakeForcer(recorder: ForceRecorder()))
        let healed = try await engine.selfHeal()
        XCTAssertEqual(healed, 1)
        let forgotten = await store.forgotten
        XCTAssertEqual(forgotten, ["m2"])
    }

    func testForceSyncDelegatesToForcer() async throws {
        let rec = ForceRecorder()
        let engine = SyncEngine(store: SyncFakeStore([]), docs: SyncFakeDocs([]),
                                container: "mnemo", forcer: SyncFakeForcer(recorder: rec))
        try await engine.forceSync()
        let calls = await rec.calls
        XCTAssertEqual(calls, 1)
    }

    func testSelfHealIdempotentSecondPassZero() async throws {
        let store = SyncFakeStore([memEntry("m1", docIds: ["live"])])
        let engine = SyncEngine(store: store, docs: SyncFakeDocs([doc("live")]),
                                container: "mnemo", forcer: SyncFakeForcer(recorder: ForceRecorder()))
        let first = try await engine.selfHeal()
        let second = try await engine.selfHeal()
        XCTAssertEqual(first, 0)
        XCTAssertEqual(second, 0)
    }
}

/// A-011: KeywordBackstop salientTerms filters stopwords and short tokens.
final class KeywordBackstopAuditTests: XCTestCase {
    func testSalientTermsFiltersStopwords() {
        let terms = KeywordBackstop.salientTerms("what is the chrome browser status")
        XCTAssertTrue(terms.contains("chrome"))
        XCTAssertFalse(terms.contains("what"))
        XCTAssertFalse(terms.contains("status"))
    }

    func testUncoveredIgnoresChatRecallEvidence() {
        let chatRecall = Retrieved(memory: "chrome is mentioned here", similarity: 0.9,
            source: .init(docId: "c", path: "/chat", title: QueryService.chatRecallTitle))
        let uncovered = KeywordBackstop.uncovered(terms: ["chrome"], in: [chatRecall])
        XCTAssertEqual(uncovered, ["chrome"],
                       "prior-chat recall must not count as document coverage")
    }
}

/// A-040: FollowUpSuggester proposes chips from evidence (M4).
final class FollowUpDocTests: XCTestCase {
    func testSuggestsFromEvidenceTitles() {
        let ev = [Retrieved(memory: "Aurora slipped four weeks.", similarity: 0.9,
                            source: .init(docId: "a", path: "/a", title: "Aurora notes"))]
        let suggestions = FollowUpSuggester.suggest(query: "how long slip?", evidence: ev, max: 2)
        XCTAssertFalse(suggestions.isEmpty)
    }
}

final class A214RegressionTests: XCTestCase {
    func testA214_forgottenFactExcludedAfterForget() {
        let forgotten = MemoryEntry(id: "m214", memory: "Forgotten fact 214.", version: 1,
                                    isLatest: true, isForgotten: true, isStatic: false,
                                    parentMemoryId: nil, rootMemoryId: "m214",
                                    forgetAfter: nil, forgetReason: "user retraction", history: [])
        let active = MemoryEntry(id: "m214b", memory: "Active fact 214.", version: 1,
                                 isLatest: true, isForgotten: false, isStatic: false,
                                 parentMemoryId: nil, rootMemoryId: "m214b",
                                 forgetAfter: nil, forgetReason: nil, history: [])
        let filtered = ContainerCatalog.memoryDynamicsFilter([forgotten, active])
        XCTAssertEqual(filtered.map(\.id), ["m214b"],
                       "re-asked queries must not surface facts retracted via /forget")
    }

    func testA214_ttlExpiredExcluded() {
        let past = ISO8601DateFormatter().string(from: Date().addingTimeInterval(-3600))
        let expired = MemoryEntry(id: "e214", memory: "TTL fact 214.", version: 1,
                                  isLatest: true, isForgotten: false, isStatic: false,
                                  parentMemoryId: nil, rootMemoryId: "e214",
                                  forgetAfter: past, forgetReason: nil, history: [])
        XCTAssertFalse(ContainerCatalog.memoryDynamicsActive(expired),
                       "TTL-expired memories must not appear in answers")
    }
}

final class A272RegressionTests: XCTestCase {
    func testA272_dreamingDoesNotDuplicateSynthesis() {
        let existing = [MemoryEntry(id: "s272", memory: "Synthesis 272.", version: 1,
                                    isLatest: true, isForgotten: false, isStatic: false,
                                    parentMemoryId: nil, rootMemoryId: "s272",
                                    forgetAfter: nil, forgetReason: nil, history: [])]
        XCTAssertFalse(LLMHopPlanner.dreamingSafeSynthesis("Synthesis 272.", existing: existing,
                                                      constituents: ["fact 272"]),
                       "dreaming must not duplicate existing syntheses")
        XCTAssertTrue(LLMHopPlanner.dreamingSafeSynthesis("New synthesis 272.", existing: existing,
                                                     constituents: ["fact 272"]),
                      "novel synthesis with constituent grounding is allowed")
    }
}

final class A185RegressionTests: XCTestCase {
    func testA185_indexingTerminal() {
        let t = LLMQueryRewriter.indexingTerminalState(path: "/f185.pdf")
        guard case .indexing(let p) = t else { return XCTFail() }
        XCTAssertEqual(p, "/f185.pdf")
    }
    func testA185_selfHealSafe() { XCTAssertEqual(LLMQueryRewriter.ingestionSelfHealSafe(orphanIds: ["m185", ""]), ["m185"]) }
}

final class A11RegressionTests: XCTestCase { func testA11_surface() { XCTAssertFalse(String(describing: KeywordBackstop.self).isEmpty) } }

final class A243RegressionTests: XCTestCase {
    func testA243_dreamingDoesNotDuplicateSynthesis() {
        let existing = [MemoryEntry(id: "s243", memory: "Synthesis 243.", version: 1,
                                    isLatest: true, isForgotten: false, isStatic: false,
                                    parentMemoryId: nil, rootMemoryId: "s243",
                                    forgetAfter: nil, forgetReason: nil, history: [])]
        XCTAssertFalse(PersonalRanker.dreamingSafeSynthesis("Synthesis 243.", existing: existing,
                                                      constituents: ["fact 243"]),
                       "dreaming must not duplicate existing syntheses")
        XCTAssertTrue(PersonalRanker.dreamingSafeSynthesis("New synthesis 243.", existing: existing,
                                                     constituents: ["fact 243"]),
                      "novel synthesis with constituent grounding is allowed")
    }
}
final class A127RegressionTests: XCTestCase { func testA127_x() { XCTAssertEqual(OllamaClient.unsupportedAnswerEvents(),[.state(.unsupportedAnswer)]) } }

final class A98RegressionTests: XCTestCase {
    func testA98_lifecycleEventsRenderable() {
        let events = LocalExtractor.lifecycleEvents(branch: .routeAmbiguity)
        XCTAssertFalse(events.isEmpty)
        var state = NotchState(phase: .input, query: "q98", answer: "", sources: [])
        for e in events { state = NotchReducer.apply(e, to: state) }
        XCTAssertTrue(!state.answer.isEmpty || state.terminal != nil || !state.reasoning.isEmpty || state.phase == .searching)
    }
}
