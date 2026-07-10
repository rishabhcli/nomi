import XCTest
@testable import MnemoOrchestrator

final class WorkSchedulerTests: XCTestCase {
    func testBackgroundYieldsWhileInteractiveInFlight() async {
        let sched = WorkScheduler()
        var yieldDuringInteractive = false
        let token = await sched.beginInteractive()
        yieldDuringInteractive = await sched.shouldBackgroundYield
        XCTAssertTrue(yieldDuringInteractive, "background must yield while an interactive query runs")
        await sched.endInteractive(token)
        let afterYield = await sched.shouldBackgroundYield
        XCTAssertFalse(afterYield, "no interactive in flight → background may run")
    }

    func testInteractivePriorityOverlaps() async {
        let sched = WorkScheduler()
        // Two interactive tasks in flight → both counted; yield stays true until both end.
        let t1 = await sched.beginInteractive()
        let t2 = await sched.beginInteractive()
        await sched.endInteractive(t1)
        let stillYield = await sched.shouldBackgroundYield
        XCTAssertTrue(stillYield, "still one interactive in flight")
        await sched.endInteractive(t2)
        let done = await sched.shouldBackgroundYield
        XCTAssertFalse(done)
    }

    func testRunInteractiveTracksLifecycle() async {
        let sched = WorkScheduler()
        let result = await sched.runInteractive { () -> Int in
            let yielding = await sched.shouldBackgroundYield
            XCTAssertTrue(yielding, "inside interactive work, background should yield")
            return 42
        }
        XCTAssertEqual(result, 42)
        let after = await sched.shouldBackgroundYield
        XCTAssertFalse(after)
    }

    func testChunkedBackgroundAbandonsWhenInteractiveArrives() async {
        let sched = WorkScheduler()
        let processed = Counter2()
        // Background processes 100 chunks but must stop early once interactive arrives.
        let bg = Task {
            await sched.runBackgroundChunked(total: 100) { i in
                await processed.set(i + 1)
                if i == 4 { let t = await sched.beginInteractive(); _ = t }  // interactive arrives at chunk 5
            }
        }
        await bg.value
        let done = await processed.value
        XCTAssertLessThan(done, 100, "background abandoned the remaining chunks for interactive")
        XCTAssertGreaterThanOrEqual(done, 5)
    }
}

    /// A-351: ResponseStyle registers M11 first-token budget and yields to interactive.
    func testResponseStyleSchedulingBudgetA351() async {
        ResponseStyle.Scheduling.registerBudget()
        XCTAssertEqual(SchedulingBudget.budgetUs(for: "ResponseStyle"), 50)
        let sched = WorkScheduler()
        let token = await sched.beginInteractive()
        await ResponseStyle.Scheduling.yieldIfInteractiveWaiting(sched)
        await sched.endInteractive(token)
    }

    /// A-352: FollowUp registers M11 first-token budget and yields to interactive.
    func testFollowUpSchedulingBudgetA352() async {
        FollowUpSuggester.Scheduling.registerBudget()
        XCTAssertEqual(SchedulingBudget.budgetUs(for: "FollowUp"), 120)
        let sched = WorkScheduler()
        let token = await sched.beginInteractive()
        await FollowUpSuggester.Scheduling.yieldIfInteractiveWaiting(sched)
        await sched.endInteractive(token)
    }

    /// A-353: Confidence registers M11 first-token budget and yields to interactive.
    func testConfidenceSchedulingBudgetA353() async {
        Confidence.Scheduling.registerBudget()
        XCTAssertEqual(SchedulingBudget.budgetUs(for: "Confidence"), 30)
        let sched = WorkScheduler()
        let token = await sched.beginInteractive()
        await Confidence.Scheduling.yieldIfInteractiveWaiting(sched)
        await sched.endInteractive(token)
    }

    /// A-354: Provenance registers M11 first-token budget and yields to interactive.
    func testProvenanceSchedulingBudgetA354() async {
        Provenance.Scheduling.registerBudget()
        XCTAssertEqual(SchedulingBudget.budgetUs(for: "Provenance"), 80)
        let sched = WorkScheduler()
        let token = await sched.beginInteractive()
        await Provenance.Scheduling.yieldIfInteractiveWaiting(sched)
        await sched.endInteractive(token)
    }

    /// A-355: CommandParser registers M11 first-token budget and yields to interactive.
    func testCommandParserSchedulingBudgetA355() async {
        CommandParser.Scheduling.registerBudget()
        XCTAssertEqual(SchedulingBudget.budgetUs(for: "CommandParser"), 40)
        let sched = WorkScheduler()
        let token = await sched.beginInteractive()
        await CommandParser.Scheduling.yieldIfInteractiveWaiting(sched)
        await sched.endInteractive(token)
    }

    /// A-356: EntityExtractor registers M11 first-token budget and yields to interactive.
    func testEntityExtractorSchedulingBudgetA356() async {
        EntityExtractor.Scheduling.registerBudget()
        XCTAssertEqual(SchedulingBudget.budgetUs(for: "EntityExtractor"), 200)
        let sched = WorkScheduler()
        let token = await sched.beginInteractive()
        await EntityExtractor.Scheduling.yieldIfInteractiveWaiting(sched)
        await sched.endInteractive(token)
    }

    /// A-357: MediaCompanion registers M11 first-token budget and yields to interactive.
    func testMediaCompanionSchedulingBudgetA357() async {
        MediaCompanion.Scheduling.registerBudget()
        XCTAssertEqual(SchedulingBudget.budgetUs(for: "MediaCompanion"), 150)
        let sched = WorkScheduler()
        let token = await sched.beginInteractive()
        await MediaCompanion.Scheduling.yieldIfInteractiveWaiting(sched)
        await sched.endInteractive(token)
    }

    /// A-358: LocalExtractor registers M11 first-token budget and yields to interactive.
    func testLocalExtractorSchedulingBudgetA358() async {
        LocalExtractor.Scheduling.registerBudget()
        XCTAssertEqual(SchedulingBudget.budgetUs(for: "LocalExtractor"), 300)
        let sched = WorkScheduler()
        let token = await sched.beginInteractive()
        await LocalExtractor.Scheduling.yieldIfInteractiveWaiting(sched)
        await sched.endInteractive(token)
    }

    /// A-359: Digest registers M11 first-token budget and yields to interactive.
    func testDigestSchedulingBudgetA359() async {
        Digest.Scheduling.registerBudget()
        XCTAssertEqual(SchedulingBudget.budgetUs(for: "Digest"), 60)
        let sched = WorkScheduler()
        let token = await sched.beginInteractive()
        await Digest.Scheduling.yieldIfInteractiveWaiting(sched)
        await sched.endInteractive(token)
    }

    /// A-360: Preferences registers M11 first-token budget and yields to interactive.
    func testPreferencesSchedulingBudgetA360() async {
        Preferences.Scheduling.registerBudget()
        XCTAssertEqual(SchedulingBudget.budgetUs(for: "Preferences"), 40)
        let sched = WorkScheduler()
        let token = await sched.beginInteractive()
        await Preferences.Scheduling.yieldIfInteractiveWaiting(sched)
        await sched.endInteractive(token)
    }

actor Counter2 { var value = 0; func set(_ v: Int) { value = v } }

final class A220RegressionTests: XCTestCase {
    func testA220_forgottenFactExcludedAfterForget() {
        let forgotten = MemoryEntry(id: "m220", memory: "Forgotten fact 220.", version: 1,
                                    isLatest: true, isForgotten: true, isStatic: false,
                                    parentMemoryId: nil, rootMemoryId: "m220",
                                    forgetAfter: nil, forgetReason: "user retraction", history: [])
        let active = MemoryEntry(id: "m220b", memory: "Active fact 220.", version: 1,
                                 isLatest: true, isForgotten: false, isStatic: false,
                                 parentMemoryId: nil, rootMemoryId: "m220b",
                                 forgetAfter: nil, forgetReason: nil, history: [])
        let filtered = LLMHopPlanner.memoryDynamicsFilter([forgotten, active])
        XCTAssertEqual(filtered.map(\.id), ["m220b"],
                       "re-asked queries must not surface facts retracted via /forget")
    }

    func testA220_ttlExpiredExcluded() {
        let past = ISO8601DateFormatter().string(from: Date().addingTimeInterval(-3600))
        let expired = MemoryEntry(id: "e220", memory: "TTL fact 220.", version: 1,
                                  isLatest: true, isForgotten: false, isStatic: false,
                                  parentMemoryId: nil, rootMemoryId: "e220",
                                  forgetAfter: past, forgetReason: nil, history: [])
        XCTAssertFalse(LLMHopPlanner.memoryDynamicsActive(expired),
                       "TTL-expired memories must not appear in answers")
    }
}

final class A133RegressionTests: XCTestCase {
    func testA133_citationIntegrity() {
        let ev = [Retrieved(memory: "User uses Bazel.", similarity: 0.9, source: .init(docId: "d133", path: "/f.md", title: "Notes"))]
        XCTAssertTrue(LLMQueryRewriter.citationIntegritySupported("User uses Bazel [Notes].", evidence: ev))
        XCTAssertFalse(LLMQueryRewriter.citationIntegritySupported("User uses CMake [Notes].", evidence: ev))
    }
    func testA133_unsupportedAnswerEvent() {
        XCTAssertEqual(LLMQueryRewriter.unsupportedAnswerEvents(), [.state(.unsupportedAnswer)])
    }
}

final class A278RegressionTests: XCTestCase {
    func testA278_dreamingDoesNotDuplicateSynthesis() {
        let existing = [MemoryEntry(id: "s278", memory: "Synthesis 278.", version: 1,
                                    isLatest: true, isForgotten: false, isStatic: false,
                                    parentMemoryId: nil, rootMemoryId: "s278",
                                    forgetAfter: nil, forgetReason: nil, history: [])]
        XCTAssertFalse(SyncEngine.dreamingSafeSynthesis("Synthesis 278.", existing: existing,
                                                      constituents: ["fact 278"]),
                       "dreaming must not duplicate existing syntheses")
        XCTAssertTrue(SyncEngine.dreamingSafeSynthesis("New synthesis 278.", existing: existing,
                                                     constituents: ["fact 278"]),
                      "novel synthesis with constituent grounding is allowed")
    }
}

final class A162RegressionTests: XCTestCase {
    func testA162_indexingTerminal() {
        let t = ContainerCatalog.indexingTerminalState(path: "/f162.pdf")
        guard case .indexing(let p) = t else { return XCTFail() }
        XCTAssertEqual(p, "/f162.pdf")
    }
    func testA162_selfHealSafe() {
        XCTAssertEqual(ContainerCatalog.ingestionSelfHealSafe(orphanIds: ["m162", ""]), ["m162"])
    }
}
final class A191RegressionTests: XCTestCase {
    func testA191_ingest() {
        XCTAssertEqual(LLMSynthesizer.indexingTerminalState(path:"/a.pdf"),.indexing(path:"/a.pdf"))
        XCTAssertEqual(LLMSynthesizer.ingestionSelfHealSafe(orphanIds:["x",""]),["x"])
    }
}

final class A249RegressionTests: XCTestCase {
    func testA249_dreamingDoesNotDuplicateSynthesis() {
        let existing = [MemoryEntry(id: "s249", memory: "Synthesis 249.", version: 1,
                                    isLatest: true, isForgotten: false, isStatic: false,
                                    parentMemoryId: nil, rootMemoryId: "s249",
                                    forgetAfter: nil, forgetReason: nil, history: [])]
        XCTAssertFalse(Confidence.dreamingSafeSynthesis("Synthesis 249.", existing: existing,
                                                      constituents: ["fact 249"]),
                       "dreaming must not duplicate existing syntheses")
        XCTAssertTrue(Confidence.dreamingSafeSynthesis("New synthesis 249.", existing: existing,
                                                     constituents: ["fact 249"]),
                      "novel synthesis with constituent grounding is allowed")
    }
}
final class A104RegressionTests: XCTestCase { func testA104_x() { XCTAssertFalse(Preferences.lifecycleEvents(branch:.emptyEvidence).isEmpty) } }

/// A-017 audit: IngestGate must not force-unwrap on retriever failure.
final class IngestGateAuditTests: XCTestCase {
    func testWaitUntilSearchableReturnsFalseOnTimeout() async {
        struct EmptyRetriever: Retrieving {
            func search(_ req: SearchRequest) async throws -> [Retrieved] { [] }
        }
        let gate = IngestGate(retriever: EmptyRetriever())
        let ok = await gate.waitUntilSearchable(probe: "missing", timeout: .milliseconds(50))
        XCTAssertFalse(ok, "timeout must not trap or surface as empty success")
    }
}

/// A-046: SMFS semantic hits resolve unknown paths via ingest metadata.
final class AgenticGrepPathResolveTests: XCTestCase {
    func testResolveUnknownHitToDocumentPath() {
        let docs = [DocumentMeta(id: "d1", filepath: "/notes/aurora.md", title: "Aurora notes",
                                 status: "done", containerTags: ["mnemo"], summary: nil, updatedAt: nil)]
        let hits = [GrepHit(path: "", lineStart: nil, lineEnd: nil,
                            snippet: "Aurora slipped four weeks per Aurora notes")]
        let resolved = SMFSGrep.resolveUnknownHits(hits, docs: docs)
        XCTAssertEqual(resolved.first?.path, "/notes/aurora.md")
    }
}
