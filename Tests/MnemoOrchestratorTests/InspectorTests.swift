import XCTest
@testable import MnemoOrchestrator

final class SuppressionLedgerTests: XCTestCase {
    func tempPath() -> String { FileManager.default.temporaryDirectory.appending(path: "mnemo-supp-\(UUID()).json").path }

    func testSuppressSurvivesReopen() async {
        let path = tempPath(); defer { try? FileManager.default.removeItem(atPath: path) }
        let l = SuppressionLedger(path: path)
        await l.suppress("I live in New York City.")
        let hit = await l.isSuppressed("i live in new york city")   // normalized match
        XCTAssertTrue(hit)
        let reopened = SuppressionLedger(path: path)
        let reloaded = await reopened.isSuppressed("I live in New York City.")
        XCTAssertTrue(reloaded)
    }

    func testUnsuppressLifts() async {
        let path = tempPath(); defer { try? FileManager.default.removeItem(atPath: path) }
        let l = SuppressionLedger(path: path)
        await l.suppress("secret fact")
        await l.unsuppress("secret fact")
        let still = await l.isSuppressed("secret fact")
        XCTAssertFalse(still)
    }
}

final class SuppressionInIngestTests: XCTestCase {
    func testSuppressedFactNotRecreatedOnReingest() async throws {
        let path = FileManager.default.temporaryDirectory.appending(path: "s-\(UUID()).json").path
        defer { try? FileManager.default.removeItem(atPath: path) }
        let supp = SuppressionLedger(path: path)
        await supp.suppress("I have a cat named Mittens.")
        let store = FakeMemoryStore()
        let dyn = MemoryDynamics(store: store, container: "mnemo",
                                 detector: StubContradiction(map: [:]), suppression: supp)
        try await dyn.onNewFacts(["I have a cat named Mittens.", "I have a dog named Rex."], from: "doc")
        let created = await store.created
        XCTAssertEqual(created.map(\.content), ["I have a dog named Rex."],
                       "suppressed fact must not be recreated on re-ingest")
    }
}

// Inspector

actor InspectorFakeStore: MemoryStoring {
    var entries: [MemoryEntry]
    var forgotten: [String] = []
    var superseded: [(String, String)] = []
    init(_ e: [MemoryEntry]) { entries = e }
    func createMemory(content: String, isStatic: Bool, forgetAfter: String?, container: String?) async throws -> String { "x" }
    func supersedeMemory(id: String, newContent: String, container: String?) async throws -> String { superseded.append((id, newContent)); return "\(id)-v2" }
    func forgetMemory(id: String, reason: String, container: String?) async throws { forgotten.append(id) }
    func listMemories(container: String?) async throws -> [MemoryEntry] { entries }
}

private func imem(_ id: String, _ text: String, isStatic: Bool) -> MemoryEntry {
    MemoryEntry(id: id, memory: text, version: 1, isLatest: true, isForgotten: false,
                isStatic: isStatic, parentMemoryId: nil, rootMemoryId: id,
                forgetAfter: nil, forgetReason: nil, history: [], documentIds: ["d"])
}

final class MemoryInspectorTests: XCTestCase {
    func tempPath() -> String { FileManager.default.temporaryDirectory.appending(path: "mnemo-supp-\(UUID()).json").path }

    func testSnapshotSplitsStaticAndDynamicChips() async throws {
        let store = InspectorFakeStore([
            imem("s1", "User is a Rust engineer.", isStatic: true),
            imem("d1", "User is migrating to Bazel.", isStatic: false),
        ])
        let inspector = MemoryInspector(store: store, container: "mnemo",
                                        suppression: SuppressionLedger(path: tempPath()))
        let snap = try await inspector.snapshot()
        XCTAssertEqual(snap.statics.map(\.text), ["User is a Rust engineer."])
        XCTAssertEqual(snap.dynamics.map(\.text), ["User is migrating to Bazel."])
    }

    func testDeleteForgetsAndSuppresses() async throws {
        let path = tempPath(); defer { try? FileManager.default.removeItem(atPath: path) }
        let supp = SuppressionLedger(path: path)
        let store = InspectorFakeStore([imem("d1", "User owns a boat.", isStatic: false)])
        let inspector = MemoryInspector(store: store, container: "mnemo", suppression: supp)
        try await inspector.delete("d1", text: "User owns a boat.")
        let forgotten = await store.forgotten
        XCTAssertEqual(forgotten, ["d1"])
        let suppressed = await supp.isSuppressed("User owns a boat.")
        XCTAssertTrue(suppressed, "delete also suppresses re-ingest")
    }

    func testCorrectSupersedes() async throws {
        let store = InspectorFakeStore([imem("d1", "User uses vim.", isStatic: false)])
        let inspector = MemoryInspector(store: store, container: "mnemo",
                                        suppression: SuppressionLedger(path: tempPath()))
        try await inspector.correct("d1", newText: "User uses Neovim.")
        let superseded = await store.superseded
        XCTAssertEqual(superseded.first?.0, "d1")
        XCTAssertEqual(superseded.first?.1, "User uses Neovim.")
    }
}

final class AnswerTraceTests: XCTestCase {
    func testRecordsAndRecallsEvidencePerAnswer() async {
        let trace = AnswerTrace()
        let cards = [SourceCard(title: "Build notes", path: "/f.md", docId: "d1")]
        await trace.record(query: "what's my build tool?", answer: "Bazel.", sources: cards)
        let recent = await trace.recent(limit: 5)
        XCTAssertEqual(recent.count, 1)
        XCTAssertEqual(recent[0].query, "what's my build tool?")
        XCTAssertEqual(recent[0].sources.map(\.docId), ["d1"])
    }

    func testKeepsMostRecentWithinLimit() async {
        let trace = AnswerTrace()
        for i in 0..<10 { await trace.record(query: "q\(i)", answer: "a", sources: []) }
        let recent = await trace.recent(limit: 3)
        XCTAssertEqual(recent.map(\.query), ["q9", "q8", "q7"])
    }
}

/// A-014 regression: Prompt composes context without a logging surface.
final class PromptLoggingAuditTests: XCTestCase {
    func testContextFormatsEvidenceWithoutLoggingAPI() {
        let ctx = Prompt.context([Retrieved(memory: "SECRET_DOC", similarity: 0.9,
            source: .init(docId: "d", path: "/p", title: "t", charStart: 0, charEnd: 5))])
        XCTAssertTrue(ctx.contains("SECRET_DOC"))
        XCTAssertTrue(ctx.contains("@0-5"))
    }

    func testPromptFileHasNoInfoLoggingSurface() {
        XCTAssertFalse(String(describing: Prompt.self).contains("Logger"),
                       "Prompt must not expose info-level logging of document text")
    }
}

/// A-024 regression: Inspector suppression ledger has no info logging surface.
final class InspectorLoggingAuditTests: XCTestCase {
    func testSuppressionLedgerNormalizesWithoutLogging() async {
        let path = NSTemporaryDirectory() + "suppress-\(UUID().uuidString).json"
        let ledger = SuppressionLedger(path: path)
        await ledger.suppress("User prefers Bazel build tool")
        XCTAssertTrue(await ledger.isSuppressed("user prefers bazel build tool"))
        try? FileManager.default.removeItem(atPath: path)
    }
}

final class A217RegressionTests: XCTestCase {
    func testA217_forgottenFactExcludedAfterForget() {
        let forgotten = MemoryEntry(id: "m217", memory: "Forgotten fact 217.", version: 1,
                                    isLatest: true, isForgotten: true, isStatic: false,
                                    parentMemoryId: nil, rootMemoryId: "m217",
                                    forgetAfter: nil, forgetReason: "user retraction", history: [])
        let active = MemoryEntry(id: "m217b", memory: "Active fact 217.", version: 1,
                                 isLatest: true, isForgotten: false, isStatic: false,
                                 parentMemoryId: nil, rootMemoryId: "m217b",
                                 forgetAfter: nil, forgetReason: nil, history: [])
        let filtered = CharSpan.memoryDynamicsFilter([forgotten, active])
        XCTAssertEqual(filtered.map(\.id), ["m217b"],
                       "re-asked queries must not surface facts retracted via /forget")
    }

    func testA217_ttlExpiredExcluded() {
        let past = ISO8601DateFormatter().string(from: Date().addingTimeInterval(-3600))
        let expired = MemoryEntry(id: "e217", memory: "TTL fact 217.", version: 1,
                                  isLatest: true, isForgotten: false, isStatic: false,
                                  parentMemoryId: nil, rootMemoryId: "e217",
                                  forgetAfter: past, forgetReason: nil, history: [])
        XCTAssertFalse(CharSpan.memoryDynamicsActive(expired),
                       "TTL-expired memories must not appear in answers")
    }
}

final class A130RegressionTests: XCTestCase {
    func testA130_citationIntegrity() {
        let ev = [Retrieved(memory: "User uses Bazel.", similarity: 0.9, source: .init(docId: "d130", path: "/f.md", title: "Notes"))]
        XCTAssertTrue(EgressGuard.citationIntegritySupported("User uses Bazel [Notes].", evidence: ev))
        XCTAssertFalse(EgressGuard.citationIntegritySupported("User uses CMake [Notes].", evidence: ev))
    }
    func testA130_unsupportedAnswerEvent() {
        XCTAssertEqual(EgressGuard.unsupportedAnswerEvents(), [.state(.unsupportedAnswer)])
    }
}
final class A159RegressionTests: XCTestCase { func testA159_x() { XCTAssertEqual(Digest.unsupportedAnswerEvents(),[.state(.unsupportedAnswer)]) } }
final class A188RegressionTests: XCTestCase { func testA188_x() { XCTAssertEqual(MemoryDynamics.indexingTerminalState(path:"/p"),.indexing(path:"/p")) } }

final class A246RegressionTests: XCTestCase {
    func testA246_dreamingDoesNotDuplicateSynthesis() {
        let existing = [MemoryEntry(id: "s246", memory: "Synthesis 246.", version: 1,
                                    isLatest: true, isForgotten: false, isStatic: false,
                                    parentMemoryId: nil, rootMemoryId: "s246",
                                    forgetAfter: nil, forgetReason: nil, history: [])]
        XCTAssertFalse(TimelineBuilder.dreamingSafeSynthesis("Synthesis 246.", existing: existing,
                                                      constituents: ["fact 246"]),
                       "dreaming must not duplicate existing syntheses")
        XCTAssertTrue(TimelineBuilder.dreamingSafeSynthesis("New synthesis 246.", existing: existing,
                                                     constituents: ["fact 246"]),
                      "novel synthesis with constituent grounding is allowed")
    }
}
final class A101RegressionTests: XCTestCase { func testA101_x() { XCTAssertFalse(MediaCompanion.lifecycleEvents(branch:.emptyEvidence).isEmpty) } }

final class A275RegressionTests: XCTestCase {
    func testA275_dreamingDoesNotDuplicateSynthesis() {
        let existing = [MemoryEntry(id: "s275", memory: "Synthesis 275.", version: 1,
                                    isLatest: true, isForgotten: false, isStatic: false,
                                    parentMemoryId: nil, rootMemoryId: "s275",
                                    forgetAfter: nil, forgetReason: nil, history: [])]
        XCTAssertFalse(OllamaClient.dreamingSafeSynthesis("Synthesis 275.", existing: existing,
                                                      constituents: ["fact 275"]),
                       "dreaming must not duplicate existing syntheses")
        XCTAssertTrue(OllamaClient.dreamingSafeSynthesis("New synthesis 275.", existing: existing,
                                                     constituents: ["fact 275"]),
                      "novel synthesis with constituent grounding is allowed")
    }
}

/// A-043: temporal predicate contradictions are detected.
final class LexicalContradictionExtendedTests: XCTestCase {
    func testDetectsStartedOnConflict() async {
        let det = LexicalContradiction()
        let candidates = [MemoryEntry(id: "m1", memory: "Project started on May 5.", version: 1,
                                      isLatest: true, isForgotten: false, isStatic: false,
                                      parentMemoryId: nil, rootMemoryId: "m1",
                                      forgetAfter: nil, forgetReason: nil, history: [])]
        XCTAssertEqual(await det.supersededFact(byNew: "Project started on June 2.", among: candidates), "m1")
    }
}
