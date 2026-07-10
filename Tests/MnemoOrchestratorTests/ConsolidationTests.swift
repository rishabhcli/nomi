import XCTest
@testable import MnemoOrchestrator

final class StrengthLedgerTests: XCTestCase {
    func tempPath() -> String {
        FileManager.default.temporaryDirectory.appending(path: "mnemo-strength-\(UUID()).json").path
    }

    func testStrengthenIncrementsAndPersists() async throws {
        let path = tempPath()
        defer { try? FileManager.default.removeItem(atPath: path) }
        let ledger = StrengthLedger(path: path)
        await ledger.strengthen("m1", at: Date(timeIntervalSince1970: 100))
        await ledger.strengthen("m1", at: Date(timeIntervalSince1970: 200))
        let rec = await ledger.record("m1")
        XCTAssertEqual(rec?.retrievalCount, 2)
        XCTAssertEqual(rec?.lastRetrieved.timeIntervalSince1970, 200)

        // A fresh ledger on the same path sees the persisted state.
        let reopened = StrengthLedger(path: path)
        let reloaded = await reopened.record("m1")
        XCTAssertEqual(reloaded?.retrievalCount, 2)
    }

    func testStrengthenedRanksHigher() async {
        let path = tempPath()
        defer { try? FileManager.default.removeItem(atPath: path) }
        let ledger = StrengthLedger(path: path)
        await ledger.strengthen("hot", at: Date())
        await ledger.strengthen("hot", at: Date())
        await ledger.strengthen("cold", at: Date())
        let ranked = await ledger.rankByStrength(["cold", "hot"])
        XCTAssertEqual(ranked, ["hot", "cold"])
    }
}

final class ColdArchivePolicyTests: XCTestCase {
    func testArchivesMemoriesUntouchedPastThreshold() {
        let now = Date(timeIntervalSince1970: 100 * 86400)
        let records: [String: StrengthRecord] = [
            "fresh": StrengthRecord(retrievalCount: 3, lastRetrieved: now.addingTimeInterval(-5 * 86400)),
            "stale": StrengthRecord(retrievalCount: 1, lastRetrieved: now.addingTimeInterval(-40 * 86400)),
        ]
        let archivable = ColdArchive.archivable(records: records, now: now, thresholdDays: 30)
        XCTAssertEqual(archivable, ["stale"])
    }
}

final class PromotionPolicyTests: XCTestCase {
    func testRecurringDynamicFactPromotable() {
        let counts = ["recurring": 4, "rare": 1]
        let ids = Promotion.promotable(retrievalCounts: counts, minAssertions: 3)
        XCTAssertEqual(ids, ["recurring"])
    }
}

// MARK: - Consolidator orchestration

actor DreamFakeStore: MemoryStoring {
    var entries: [MemoryEntry]
    var created: [(content: String, isStatic: Bool)] = []
    var forgotten: [String] = []
    init(_ e: [MemoryEntry]) { entries = e }
    func createMemory(content: String, isStatic: Bool, forgetAfter: String?, container: String?) async throws -> String {
        created.append((content, isStatic)); return "new-\(created.count)"
    }
    func supersedeMemory(id: String, newContent: String, container: String?) async throws -> String { id }
    func forgetMemory(id: String, reason: String, container: String?) async throws { forgotten.append(id) }
    func listMemories(container: String?) async throws -> [MemoryEntry] { entries }
}

struct StubSynthesizer: PatternSynthesizing {
    let output: String?
    func synthesize(_ cluster: [MemoryEntry]) async -> String? { output }
}

private func dmem(_ id: String, _ text: String, isStatic: Bool = false) -> MemoryEntry {
    MemoryEntry(id: id, memory: text, version: 1, isLatest: true, isForgotten: false,
                isStatic: isStatic, parentMemoryId: nil, rootMemoryId: id,
                forgetAfter: nil, forgetReason: nil, history: [], documentIds: ["d"])
}

final class ConsolidatorTests: XCTestCase {
    func tempPath() -> String { FileManager.default.temporaryDirectory.appending(path: "mnemo-str-\(UUID()).json").path }

    func testDreamPromotesRecurringDynamicToStatic() async throws {
        let path = tempPath(); defer { try? FileManager.default.removeItem(atPath: path) }
        let store = DreamFakeStore([dmem("m1", "I prefer dark roast coffee.")])
        let ledger = StrengthLedger(path: path)
        for _ in 0..<3 { await ledger.strengthen("m1", at: Date()) }
        let c = Consolidator(store: store, ledger: ledger, container: "mnemo",
                             synthesizer: StubSynthesizer(output: nil),
                             coldThresholdDays: 30, promoteMinAssertions: 3)
        try await c.dream(now: Date())
        let created = await store.created
        XCTAssertTrue(created.contains { $0.content == "I prefer dark roast coffee." && $0.isStatic })
        let forgotten = await store.forgotten
        XCTAssertTrue(forgotten.contains("m1"), "the dynamic original is retired after promotion")
    }

    func testDreamSynthesizesClusterCitingConstituents() async throws {
        let path = tempPath(); defer { try? FileManager.default.removeItem(atPath: path) }
        let store = DreamFakeStore([
            dmem("m1", "I use Bazel for the renderer."),
            dmem("m2", "I use Bazel for the server."),
            dmem("m3", "I migrated the mobile app to Bazel."),
        ])
        let c = Consolidator(store: store, ledger: StrengthLedger(path: path), container: "mnemo",
                             synthesizer: StubSynthesizer(output: "The user standardizes on Bazel across all projects."),
                             coldThresholdDays: 30, promoteMinAssertions: 99)   // no promotion
        try await c.dream(now: Date())
        let created = await store.created
        XCTAssertTrue(created.contains { $0.content.contains("standardizes on Bazel") })
    }

    func testDreamArchivesColdMemories() async throws {
        let path = tempPath(); defer { try? FileManager.default.removeItem(atPath: path) }
        let store = DreamFakeStore([dmem("cold", "An old ephemeral note.")])
        let ledger = StrengthLedger(path: path)
        await ledger.strengthen("cold", at: Date(timeIntervalSince1970: 0))   // touched long ago
        let c = Consolidator(store: store, ledger: ledger, container: "mnemo",
                             synthesizer: StubSynthesizer(output: nil),
                             coldThresholdDays: 30, promoteMinAssertions: 3)
        try await c.dream(now: Date(timeIntervalSince1970: 100 * 86400))
        let forgotten = await store.forgotten
        XCTAssertTrue(forgotten.contains("cold"))
    }

    // Regression: repeated dream passes must not accrete duplicate syntheses.
    func testDreamDoesNotDuplicateExistingSynthesis() async throws {
        let path = tempPath(); defer { try? FileManager.default.removeItem(atPath: path) }
        let synth = "The user standardizes on Bazel across all projects."
        let store = DreamFakeStore([
            dmem("m1", "I use Bazel for the renderer."),
            dmem("m2", "I use Bazel for the server."),
            dmem("m3", "I migrated the mobile app to Bazel."),
            dmem("m4", synth),   // a prior dream pass already synthesized this
        ])
        let c = Consolidator(store: store, ledger: StrengthLedger(path: path), container: "mnemo",
                             synthesizer: StubSynthesizer(output: synth),
                             coldThresholdDays: 30, promoteMinAssertions: 99)
        try await c.dream(now: Date())
        let created = await store.created
        XCTAssertFalse(created.contains { ProfileDedupe.normalize($0.content) == ProfileDedupe.normalize(synth) },
                       "a synthesis identical to an existing memory must not be re-created (idempotent dreaming)")
    }
}

/// A-013 invariant: ContextAssembler constructs no URLs.
final class ContextAssemblerInvariantTests: XCTestCase {
    func testAssembleUsesProfileAndEvidenceOnly() {
        let ctx = ContextAssembler(tokenBudget: 1000).assemble(
            intent: .lookup, question: "q",
            profile: Profile(statics: ["likes Bazel"], dynamics: []),
            evidence: [Retrieved(memory: "evidence text", similarity: 0.9,
                                 source: .init(docId: "d", path: "/p", title: "t"))])
        XCTAssertTrue(ctx.preamble.contains("Bazel"))
        XCTAssertEqual(ctx.evidence.count, 1)
    }

    func testAssemblerNeverConstructsURLs() {
        let assembler = ContextAssembler(tokenBudget: 500)
        let ctx = assembler.assemble(intent: .lookup, question: "q",
            profile: Profile(statics: [], dynamics: [], memories: []), evidence: [])
        XCTAssertFalse(ctx.preamble.contains("http://") && !ctx.preamble.contains("127.0.0.1"))
        XCTAssertTrue(ctx.evidence.isEmpty)
    }
}

final class A216RegressionTests: XCTestCase {
    func testA216_forgottenFactExcludedAfterForget() {
        let forgotten = MemoryEntry(id: "m216", memory: "Forgotten fact 216.", version: 1,
                                    isLatest: true, isForgotten: true, isStatic: false,
                                    parentMemoryId: nil, rootMemoryId: "m216",
                                    forgetAfter: nil, forgetReason: "user retraction", history: [])
        let active = MemoryEntry(id: "m216b", memory: "Active fact 216.", version: 1,
                                 isLatest: true, isForgotten: false, isStatic: false,
                                 parentMemoryId: nil, rootMemoryId: "m216b",
                                 forgetAfter: nil, forgetReason: nil, history: [])
        let filtered = SpanResolver.memoryDynamicsFilter([forgotten, active])
        XCTAssertEqual(filtered.map(\.id), ["m216b"],
                       "re-asked queries must not surface facts retracted via /forget")
    }

    func testA216_ttlExpiredExcluded() {
        let past = ISO8601DateFormatter().string(from: Date().addingTimeInterval(-3600))
        let expired = MemoryEntry(id: "e216", memory: "TTL fact 216.", version: 1,
                                  isLatest: true, isForgotten: false, isStatic: false,
                                  parentMemoryId: nil, rootMemoryId: "e216",
                                  forgetAfter: past, forgetReason: nil, history: [])
        XCTAssertFalse(SpanResolver.memoryDynamicsActive(expired),
                       "TTL-expired memories must not appear in answers")
    }
}

final class A129RegressionTests: XCTestCase {
    func testA129_citationIntegrity() {
        let ev = [Retrieved(memory: "User uses Bazel.", similarity: 0.9, source: .init(docId: "d129", path: "/f.md", title: "Notes"))]
        XCTAssertTrue(ProfileDedupe.citationIntegritySupported("User uses Bazel [Notes].", evidence: ev))
        XCTAssertFalse(ProfileDedupe.citationIntegritySupported("User uses CMake [Notes].", evidence: ev))
    }
    func testA129_unsupportedAnswerEvent() {
        XCTAssertEqual(ProfileDedupe.unsupportedAnswerEvents(), [.state(.unsupportedAnswer)])
    }
}

final class A274RegressionTests: XCTestCase {
    func testA274_dreamingDoesNotDuplicateSynthesis() {
        let existing = [MemoryEntry(id: "s274", memory: "Synthesis 274.", version: 1,
                                    isLatest: true, isForgotten: false, isStatic: false,
                                    parentMemoryId: nil, rootMemoryId: "s274",
                                    forgetAfter: nil, forgetReason: nil, history: [])]
        XCTAssertFalse(Prompt.dreamingSafeSynthesis("Synthesis 274.", existing: existing,
                                                      constituents: ["fact 274"]),
                       "dreaming must not duplicate existing syntheses")
        XCTAssertTrue(Prompt.dreamingSafeSynthesis("New synthesis 274.", existing: existing,
                                                     constituents: ["fact 274"]),
                      "novel synthesis with constituent grounding is allowed")
    }
}
final class A158RegressionTests: XCTestCase { func testA158_x() { XCTAssertEqual(LocalExtractor.unsupportedAnswerEvents(),[.state(.unsupportedAnswer)]) } }
final class A187RegressionTests: XCTestCase { func testA187_x() { XCTAssertEqual(ContentHash.indexingTerminalState(path:"/p"),.indexing(path:"/p")) } }

final class A245RegressionTests: XCTestCase {
    func testA245_dreamingDoesNotDuplicateSynthesis() {
        let existing = [MemoryEntry(id: "s245", memory: "Synthesis 245.", version: 1,
                                    isLatest: true, isForgotten: false, isStatic: false,
                                    parentMemoryId: nil, rootMemoryId: "s245",
                                    forgetAfter: nil, forgetReason: nil, history: [])]
        XCTAssertFalse(TimeWindow.dreamingSafeSynthesis("Synthesis 245.", existing: existing,
                                                      constituents: ["fact 245"]),
                       "dreaming must not duplicate existing syntheses")
        XCTAssertTrue(TimeWindow.dreamingSafeSynthesis("New synthesis 245.", existing: existing,
                                                     constituents: ["fact 245"]),
                      "novel synthesis with constituent grounding is allowed")
    }
}

final class A100RegressionTests: XCTestCase {
    func testA100_lifecycleEventsRenderable() {
        let events = Preferences.lifecycleEvents(branch: .retry)
        XCTAssertFalse(events.isEmpty)
        var state = NotchState(phase: .input, query: "q100", answer: "", sources: [])
        for e in events { state = NotchReducer.apply(e, to: state) }
        XCTAssertTrue(!state.answer.isEmpty || state.terminal != nil || !state.reasoning.isEmpty || state.phase == .searching)
    }
}

/// A-042: fuzzy suppression keys survive re-extraction with different wording.
final class SuppressionFuzzyKeyTests: XCTestCase {
    func testReextractedWordingStaysSuppressed() async {
        let path = NSTemporaryDirectory() + "suppress-\(UUID().uuidString).json"
        let ledger = SuppressionLedger(path: path)
        await ledger.suppress("User prefers the Bazel build tool.")
        XCTAssertTrue(await ledger.isSuppressed("User prefers Bazel build tool"))
        try? FileManager.default.removeItem(atPath: path)
    }
}
