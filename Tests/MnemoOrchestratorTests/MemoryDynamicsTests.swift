import XCTest
@testable import MnemoOrchestrator

/// Records engine memory mutations for assertions.
actor FakeMemoryStore: MemoryStoring {
    struct Created: Equatable { let content: String; let isStatic: Bool; let forgetAfter: String? }
    var created: [Created] = []
    var superseded: [(id: String, newContent: String)] = []
    var forgotten: [(id: String, reason: String)] = []
    var entries: [MemoryEntry]

    init(entries: [MemoryEntry] = []) { self.entries = entries }

    func createMemory(content: String, isStatic: Bool, forgetAfter: String?, container: String?) async throws -> String {
        created.append(Created(content: content, isStatic: isStatic, forgetAfter: forgetAfter))
        return "new-\(created.count)"
    }
    func supersedeMemory(id: String, newContent: String, container: String?) async throws -> String {
        superseded.append((id, newContent)); return "\(id)-v2"
    }
    func forgetMemory(id: String, reason: String, container: String?) async throws {
        forgotten.append((id, reason))
    }
    func listMemories(container: String?) async throws -> [MemoryEntry] { entries }
}

/// Scriptable contradiction detector.
struct StubContradiction: ContradictionDetecting {
    let map: [String: String]   // newFact → existing id it supersedes
    func supersededFact(byNew newFact: String, among candidates: [MemoryEntry]) async -> String? {
        map[newFact]
    }
}

private func entry(_ id: String, _ text: String, isStatic: Bool = false) -> MemoryEntry {
    MemoryEntry(id: id, memory: text, version: 1, isLatest: true, isForgotten: false,
                isStatic: isStatic, parentMemoryId: nil, rootMemoryId: id,
                forgetAfter: nil, forgetReason: nil, history: [])
}

final class LexicalContradictionTests: XCTestCase {
    let det = LexicalContradiction()

    func testSameSubjectPredicateDifferentObjectContradicts() async {
        let candidates = [entry("m1", "I live in New York City.")]
        let hit = await det.supersededFact(byNew: "I live in San Francisco.", among: candidates)
        XCTAssertEqual(hit, "m1")
    }

    func testDifferentPredicateDoesNotContradict() async {
        let candidates = [entry("m1", "I live in New York City.")]
        let hit = await det.supersededFact(byNew: "I work in Boston.", among: candidates)
        XCTAssertNil(hit)
    }

    func testSameFactIsNotAContradiction() async {
        let candidates = [entry("m1", "I live in New York City.")]
        let hit = await det.supersededFact(byNew: "I live in New York City.", among: candidates)
        XCTAssertNil(hit, "identical object is not a contradiction")
    }
}

final class MemoryDynamicsTests: XCTestCase {
    func testNewContradictingFactSupersedesInPlace() async throws {
        let store = FakeMemoryStore(entries: [entry("m1", "I live in New York City.")])
        let dyn = MemoryDynamics(store: store, container: "mnemo",
                                 detector: StubContradiction(map: ["I moved to San Francisco.": "m1"]))
        try await dyn.onNewFacts(["I moved to San Francisco."], from: "doc1")
        let superseded = await store.superseded
        let created = await store.created
        XCTAssertEqual(superseded.map(\.id), ["m1"])
        XCTAssertEqual(superseded.first?.newContent, "I moved to San Francisco.")
        XCTAssertTrue(created.isEmpty, "contradiction supersedes, never duplicates")
    }

    func testNovelFactIsCreated() async throws {
        let store = FakeMemoryStore(entries: [entry("m1", "I live in NYC.")])
        let dyn = MemoryDynamics(store: store, container: "mnemo",
                                 detector: StubContradiction(map: [:]))
        try await dyn.onNewFacts(["I have a dog named Rex."], from: "doc1")
        let created = await store.created
        XCTAssertEqual(created.map(\.content), ["I have a dog named Rex."])
        let superseded = await store.superseded
        XCTAssertTrue(superseded.isEmpty)
    }

    func testSoftDeletePassesReason() async throws {
        let store = FakeMemoryStore()
        let dyn = MemoryDynamics(store: store, container: "mnemo", detector: StubContradiction(map: [:]))
        try await dyn.softDelete("m9", reason: .userRetraction)
        let forgotten = await store.forgotten
        XCTAssertEqual(forgotten.first?.id, "m9")
        XCTAssertEqual(forgotten.first?.reason, "user retraction")
    }

    func testHistoryReturnsVersionChain() async throws {
        let v1 = MemoryVersion(memory: "I live in NYC.", version: 1)
        let latest = MemoryEntry(id: "m2", memory: "I moved to SF.", version: 2, isLatest: true,
                                 isForgotten: false, isStatic: false, parentMemoryId: "m1",
                                 rootMemoryId: "m1", forgetAfter: nil, forgetReason: nil, history: [v1])
        let store = FakeMemoryStore(entries: [latest])
        let dyn = MemoryDynamics(store: store, container: "mnemo", detector: StubContradiction(map: [:]))
        let hist = try await dyn.history(of: "m1")
        XCTAssertEqual(hist.map(\.memory), ["I moved to SF.", "I live in NYC."])
    }
}

final class MemoryEntryDecodeTests: XCTestCase {
    func testDecodesListEntry() throws {
        let json = """
        {"memoryEntries":[{"id":"m2","memory":"I moved to SF.","version":2,"isLatest":true,
          "isForgotten":false,"isStatic":false,"parentMemoryId":"m1","rootMemoryId":"m1",
          "forgetAfter":null,"forgetReason":null,
          "history":[{"memory":"I live in NYC.","version":1}]}],
         "pagination":{"currentPage":1,"totalPages":1}}
        """
        let page = try JSONDecoder().decode(EngineClient.MemoryListPage.self, from: Data(json.utf8))
        XCTAssertEqual(page.memoryEntries.count, 1)
        XCTAssertEqual(page.memoryEntries[0].version, 2)
        XCTAssertEqual(page.memoryEntries[0].history.first?.memory, "I live in NYC.")
    }
}

/// A-012 audit: LLMHopPlanner must not force-unwrap or silently fail on bad output.
final class LLMHopPlannerAuditTests: XCTestCase {
    func testParseUnparseableOutputStopsWithRationale() {
        let decision = LLMHopPlanner.parse("```not valid json```")
        if case .stop(let why) = decision {
            XCTAssertEqual(why, "planner output unparseable")
        } else {
            XCTFail("expected stop on unparseable planner output")
        }
    }

    func testParseSemanticWithoutQueryStopsSafely() {
        let decision = LLMHopPlanner.parse(#"{"action":"semantic","rationale":"no query"}"#)
        if case .stop = decision { } else { XCTFail("missing query must not force-unwrap") }
    }
}

final class A215RegressionTests: XCTestCase {
    func testA215_forgottenFactExcludedAfterForget() {
        let forgotten = MemoryEntry(id: "m215", memory: "Forgotten fact 215.", version: 1,
                                    isLatest: true, isForgotten: true, isStatic: false,
                                    parentMemoryId: nil, rootMemoryId: "m215",
                                    forgetAfter: nil, forgetReason: "user retraction", history: [])
        let active = MemoryEntry(id: "m215b", memory: "Active fact 215.", version: 1,
                                 isLatest: true, isForgotten: false, isStatic: false,
                                 parentMemoryId: nil, rootMemoryId: "m215b",
                                 forgetAfter: nil, forgetReason: nil, history: [])
        let filtered = CitationVerifier.memoryDynamicsFilter([forgotten, active])
        XCTAssertEqual(filtered.map(\.id), ["m215b"],
                       "re-asked queries must not surface facts retracted via /forget")
    }

    func testA215_ttlExpiredExcluded() {
        let past = ISO8601DateFormatter().string(from: Date().addingTimeInterval(-3600))
        let expired = MemoryEntry(id: "e215", memory: "TTL fact 215.", version: 1,
                                  isLatest: true, isForgotten: false, isStatic: false,
                                  parentMemoryId: nil, rootMemoryId: "e215",
                                  forgetAfter: past, forgetReason: nil, history: [])
        XCTAssertFalse(CitationVerifier.memoryDynamicsActive(expired),
                       "TTL-expired memories must not appear in answers")
    }
}

final class A273RegressionTests: XCTestCase {
    func testA273_dreamingDoesNotDuplicateSynthesis() {
        let existing = [MemoryEntry(id: "s273", memory: "Synthesis 273.", version: 1,
                                    isLatest: true, isForgotten: false, isStatic: false,
                                    parentMemoryId: nil, rootMemoryId: "s273",
                                    forgetAfter: nil, forgetReason: nil, history: [])]
        XCTAssertFalse(ContextAssembler.dreamingSafeSynthesis("Synthesis 273.", existing: existing,
                                                      constituents: ["fact 273"]),
                       "dreaming must not duplicate existing syntheses")
        XCTAssertTrue(ContextAssembler.dreamingSafeSynthesis("New synthesis 273.", existing: existing,
                                                     constituents: ["fact 273"]),
                      "novel synthesis with constituent grounding is allowed")
    }
}

final class A281RegressionTests: XCTestCase {
    func testA281_expressivenessTimelineShape() {
        let items = ["Event A 281", "Event B 281"]
        let shaped = ConflictDetector.expressivenessShape(items, as: .timeline)
        XCTAssertTrue(shaped.contains("1. Event A 281"), "timeline shaping for offline synthesis")
        XCTAssertTrue(shaped.contains("2. Event B 281"))
    }

    func testA281_expressivenessBulletShape() {
        let shaped = ConflictDetector.expressivenessShape(["Point 281"], as: .list)
        XCTAssertTrue(shaped.hasPrefix("- "), "bullet shaping beats cloud-dependent formatting")
    }
}

final class A282RegressionTests: XCTestCase {
    func testA282_expressivenessTimelineShape() {
        let items = ["Event A 282", "Event B 282"]
        let shaped = ColdArchive.expressivenessShape(items, as: .timeline)
        XCTAssertTrue(shaped.contains("1. Event A 282"), "timeline shaping for offline synthesis")
        XCTAssertTrue(shaped.contains("2. Event B 282"))
    }

    func testA282_expressivenessBulletShape() {
        let shaped = ColdArchive.expressivenessShape(["Point 282"], as: .list)
        XCTAssertTrue(shaped.hasPrefix("- "), "bullet shaping beats cloud-dependent formatting")
    }
}

final class A285RegressionTests: XCTestCase {
    func testA285_expressivenessTimelineShape() {
        let items = ["Event A 285", "Event B 285"]
        let shaped = ProfileDedupe.expressivenessShape(items, as: .timeline)
        XCTAssertTrue(shaped.contains("1. Event A 285"), "timeline shaping for offline synthesis")
        XCTAssertTrue(shaped.contains("2. Event B 285"))
    }

    func testA285_expressivenessBulletShape() {
        let shaped = ProfileDedupe.expressivenessShape(["Point 285"], as: .list)
        XCTAssertTrue(shaped.hasPrefix("- "), "bullet shaping beats cloud-dependent formatting")
    }
}

final class A293RegressionTests: XCTestCase {
    func testA293_expressivenessTimelineShape() {
        let items = ["Event A 293", "Event B 293"]
        let shaped = AnswerCache.expressivenessShape(items, as: .timeline)
        XCTAssertTrue(shaped.contains("1. Event A 293"), "timeline shaping for offline synthesis")
        XCTAssertTrue(shaped.contains("2. Event B 293"))
    }

    func testA293_expressivenessBulletShape() {
        let shaped = AnswerCache.expressivenessShape(["Point 293"], as: .list)
        XCTAssertTrue(shaped.hasPrefix("- "), "bullet shaping beats cloud-dependent formatting")
    }
}

final class A294RegressionTests: XCTestCase {
    func testA294_expressivenessTimelineShape() {
        let items = ["Event A 294", "Event B 294"]
        let shaped = QueryHistory.expressivenessShape(items, as: .timeline)
        XCTAssertTrue(shaped.contains("1. Event A 294"), "timeline shaping for offline synthesis")
        XCTAssertTrue(shaped.contains("2. Event B 294"))
    }

    func testA294_expressivenessBulletShape() {
        let shaped = QueryHistory.expressivenessShape(["Point 294"], as: .list)
        XCTAssertTrue(shaped.hasPrefix("- "), "bullet shaping beats cloud-dependent formatting")
    }
}

final class A295RegressionTests: XCTestCase {
    func testA295_expressivenessTimelineShape() {
        let items = ["Event A 295", "Event B 295"]
        let shaped = PersonalRanker.expressivenessShape(items, as: .timeline)
        XCTAssertTrue(shaped.contains("1. Event A 295"), "timeline shaping for offline synthesis")
        XCTAssertTrue(shaped.contains("2. Event B 295"))
    }

    func testA295_expressivenessBulletShape() {
        let shaped = PersonalRanker.expressivenessShape(["Point 295"], as: .list)
        XCTAssertTrue(shaped.hasPrefix("- "), "bullet shaping beats cloud-dependent formatting")
    }
}

final class A296RegressionTests: XCTestCase {
    func testA296_expressivenessTimelineShape() {
        let items = ["Event A 296", "Event B 296"]
        let shaped = NumericReasoner.expressivenessShape(items, as: .timeline)
        XCTAssertTrue(shaped.contains("1. Event A 296"), "timeline shaping for offline synthesis")
        XCTAssertTrue(shaped.contains("2. Event B 296"))
    }

    func testA296_expressivenessBulletShape() {
        let shaped = NumericReasoner.expressivenessShape(["Point 296"], as: .list)
        XCTAssertTrue(shaped.hasPrefix("- "), "bullet shaping beats cloud-dependent formatting")
    }
}

final class A297RegressionTests: XCTestCase {
    func testA297_expressivenessTimelineShape() {
        let items = ["Event A 297", "Event B 297"]
        let shaped = TimeWindow.expressivenessShape(items, as: .timeline)
        XCTAssertTrue(shaped.contains("1. Event A 297"), "timeline shaping for offline synthesis")
        XCTAssertTrue(shaped.contains("2. Event B 297"))
    }

    func testA297_expressivenessBulletShape() {
        let shaped = TimeWindow.expressivenessShape(["Point 297"], as: .list)
        XCTAssertTrue(shaped.hasPrefix("- "), "bullet shaping beats cloud-dependent formatting")
    }
}

final class A298RegressionTests: XCTestCase {
    func testA298_expressivenessTimelineShape() {
        let items = ["Event A 298", "Event B 298"]
        let shaped = TimelineBuilder.expressivenessShape(items, as: .timeline)
        XCTAssertTrue(shaped.contains("1. Event A 298"), "timeline shaping for offline synthesis")
        XCTAssertTrue(shaped.contains("2. Event B 298"))
    }

    func testA298_expressivenessBulletShape() {
        let shaped = TimelineBuilder.expressivenessShape(["Point 298"], as: .list)
        XCTAssertTrue(shaped.hasPrefix("- "), "bullet shaping beats cloud-dependent formatting")
    }
}

final class A299RegressionTests: XCTestCase {
    func testA299_expressivenessTimelineShape() {
        let items = ["Event A 299", "Event B 299"]
        let shaped = ResponseStyle.expressivenessShape(items, as: .timeline)
        XCTAssertTrue(shaped.contains("1. Event A 299"), "timeline shaping for offline synthesis")
        XCTAssertTrue(shaped.contains("2. Event B 299"))
    }

    func testA299_expressivenessBulletShape() {
        let shaped = ResponseStyle.expressivenessShape(["Point 299"], as: .list)
        XCTAssertTrue(shaped.hasPrefix("- "), "bullet shaping beats cloud-dependent formatting")
    }
}

final class A300RegressionTests: XCTestCase {
    func testA300_expressivenessTimelineShape() {
        let items = ["Event A 300", "Event B 300"]
        let shaped = FollowUpSuggester.expressivenessShape(items, as: .timeline)
        XCTAssertTrue(shaped.contains("1. Event A 300"), "timeline shaping for offline synthesis")
        XCTAssertTrue(shaped.contains("2. Event B 300"))
    }

    func testA300_expressivenessBulletShape() {
        let shaped = FollowUpSuggester.expressivenessShape(["Point 300"], as: .list)
        XCTAssertTrue(shaped.hasPrefix("- "), "bullet shaping beats cloud-dependent formatting")
    }
}

final class A301RegressionTests: XCTestCase {
    func testA301_expressivenessTimelineShape() {
        let items = ["Event A 301", "Event B 301"]
        let shaped = Confidence.expressivenessShape(items, as: .timeline)
        XCTAssertTrue(shaped.contains("1. Event A 301"), "timeline shaping for offline synthesis")
        XCTAssertTrue(shaped.contains("2. Event B 301"))
    }

    func testA301_expressivenessBulletShape() {
        let shaped = Confidence.expressivenessShape(["Point 301"], as: .list)
        XCTAssertTrue(shaped.hasPrefix("- "), "bullet shaping beats cloud-dependent formatting")
    }
}

final class A304RegressionTests: XCTestCase {
    func testA304_expressivenessTimelineShape() {
        let items = ["Event A 304", "Event B 304"]
        let shaped = EntityExtractor.expressivenessShape(items, as: .timeline)
        XCTAssertTrue(shaped.contains("1. Event A 304"), "timeline shaping for offline synthesis")
        XCTAssertTrue(shaped.contains("2. Event B 304"))
    }

    func testA304_expressivenessBulletShape() {
        let shaped = EntityExtractor.expressivenessShape(["Point 304"], as: .list)
        XCTAssertTrue(shaped.hasPrefix("- "), "bullet shaping beats cloud-dependent formatting")
    }
}

final class A305RegressionTests: XCTestCase {
    func testA305_expressivenessTimelineShape() {
        let items = ["Event A 305", "Event B 305"]
        let shaped = MediaCompanion.expressivenessShape(items, as: .timeline)
        XCTAssertTrue(shaped.contains("1. Event A 305"), "timeline shaping for offline synthesis")
        XCTAssertTrue(shaped.contains("2. Event B 305"))
    }

    func testA305_expressivenessBulletShape() {
        let shaped = MediaCompanion.expressivenessShape(["Point 305"], as: .list)
        XCTAssertTrue(shaped.hasPrefix("- "), "bullet shaping beats cloud-dependent formatting")
    }
}

final class A306RegressionTests: XCTestCase {
    func testA306_expressivenessTimelineShape() {
        let items = ["Event A 306", "Event B 306"]
        let shaped = LocalExtractor.expressivenessShape(items, as: .timeline)
        XCTAssertTrue(shaped.contains("1. Event A 306"), "timeline shaping for offline synthesis")
        XCTAssertTrue(shaped.contains("2. Event B 306"))
    }

    func testA306_expressivenessBulletShape() {
        let shaped = LocalExtractor.expressivenessShape(["Point 306"], as: .list)
        XCTAssertTrue(shaped.hasPrefix("- "), "bullet shaping beats cloud-dependent formatting")
    }
}

final class A307RegressionTests: XCTestCase {
    func testA307_expressivenessTimelineShape() {
        let items = ["Event A 307", "Event B 307"]
        let shaped = Digest.expressivenessShape(items, as: .timeline)
        XCTAssertTrue(shaped.contains("1. Event A 307"), "timeline shaping for offline synthesis")
        XCTAssertTrue(shaped.contains("2. Event B 307"))
    }

    func testA307_expressivenessBulletShape() {
        let shaped = Digest.expressivenessShape(["Point 307"], as: .list)
        XCTAssertTrue(shaped.hasPrefix("- "), "bullet shaping beats cloud-dependent formatting")
    }
}

final class A308RegressionTests: XCTestCase {
    func testA308_expressivenessTimelineShape() {
        let items = ["Event A 308", "Event B 308"]
        let shaped = Preferences.expressivenessShape(items, as: .timeline)
        XCTAssertTrue(shaped.contains("1. Event A 308"), "timeline shaping for offline synthesis")
        XCTAssertTrue(shaped.contains("2. Event B 308"))
    }

    func testA308_expressivenessBulletShape() {
        let shaped = Preferences.expressivenessShape(["Point 308"], as: .list)
        XCTAssertTrue(shaped.hasPrefix("- "), "bullet shaping beats cloud-dependent formatting")
    }
}

final class A309RegressionTests: XCTestCase {
    func testA309_expressivenessTimelineShape() {
        let items = ["Event A 309", "Event B 309"]
        let shaped = Coverage.expressivenessShape(items, as: .timeline)
        XCTAssertTrue(shaped.contains("1. Event A 309"), "timeline shaping for offline synthesis")
        XCTAssertTrue(shaped.contains("2. Event B 309"))
    }

    func testA309_expressivenessBulletShape() {
        let shaped = Coverage.expressivenessShape(["Point 309"], as: .list)
        XCTAssertTrue(shaped.hasPrefix("- "), "bullet shaping beats cloud-dependent formatting")
    }
}

final class A310RegressionTests: XCTestCase {
    func testA310_expressivenessTimelineShape() {
        let items = ["Event A 310", "Event B 310"]
        let shaped = Highlight.expressivenessShape(items, as: .timeline)
        XCTAssertTrue(shaped.contains("1. Event A 310"), "timeline shaping for offline synthesis")
        XCTAssertTrue(shaped.contains("2. Event B 310"))
    }

    func testA310_expressivenessBulletShape() {
        let shaped = Highlight.expressivenessShape(["Point 310"], as: .list)
        XCTAssertTrue(shaped.hasPrefix("- "), "bullet shaping beats cloud-dependent formatting")
    }
}

final class A311RegressionTests: XCTestCase {
    func testA311_expressivenessTimelineShape() {
        let items = ["Event A 311", "Event B 311"]
        let shaped = ActionExtractor.expressivenessShape(items, as: .timeline)
        XCTAssertTrue(shaped.contains("1. Event A 311"), "timeline shaping for offline synthesis")
        XCTAssertTrue(shaped.contains("2. Event B 311"))
    }

    func testA311_expressivenessBulletShape() {
        let shaped = ActionExtractor.expressivenessShape(["Point 311"], as: .list)
        XCTAssertTrue(shaped.hasPrefix("- "), "bullet shaping beats cloud-dependent formatting")
    }
}

final class A312RegressionTests: XCTestCase {
    func testA312_expressivenessTimelineShape() {
        let items = ["Event A 312", "Event B 312"]
        let shaped = CorpusSuggester.expressivenessShape(items, as: .timeline)
        XCTAssertTrue(shaped.contains("1. Event A 312"), "timeline shaping for offline synthesis")
        XCTAssertTrue(shaped.contains("2. Event B 312"))
    }

    func testA312_expressivenessBulletShape() {
        let shaped = CorpusSuggester.expressivenessShape(["Point 312"], as: .list)
        XCTAssertTrue(shaped.hasPrefix("- "), "bullet shaping beats cloud-dependent formatting")
    }
}

final class A313RegressionTests: XCTestCase {
    func testA313_expressivenessTimelineShape() {
        let items = ["Event A 313", "Event B 313"]
        let shaped = QueryService.expressivenessShape(items, as: .timeline)
        XCTAssertTrue(shaped.contains("1. Event A 313"), "timeline shaping for offline synthesis")
        XCTAssertTrue(shaped.contains("2. Event B 313"))
    }

    func testA313_expressivenessBulletShape() {
        let shaped = QueryService.expressivenessShape(["Point 313"], as: .list)
        XCTAssertTrue(shaped.hasPrefix("- "), "bullet shaping beats cloud-dependent formatting")
    }
}

final class A314RegressionTests: XCTestCase {
    func testA314_expressivenessTimelineShape() {
        let items = ["Event A 314", "Event B 314"]
        let shaped = HeuristicRouter.expressivenessShape(items, as: .timeline)
        XCTAssertTrue(shaped.contains("1. Event A 314"), "timeline shaping for offline synthesis")
        XCTAssertTrue(shaped.contains("2. Event B 314"))
    }

    func testA314_expressivenessBulletShape() {
        let shaped = HeuristicRouter.expressivenessShape(["Point 314"], as: .list)
        XCTAssertTrue(shaped.hasPrefix("- "), "bullet shaping beats cloud-dependent formatting")
    }
}

final class A315RegressionTests: XCTestCase {
    func testA315_expressivenessTimelineShape() {
        let items = ["Event A 315", "Event B 315"]
        let shaped = LLMRouterEscalator.expressivenessShape(items, as: .timeline)
        XCTAssertTrue(shaped.contains("1. Event A 315"), "timeline shaping for offline synthesis")
        XCTAssertTrue(shaped.contains("2. Event B 315"))
    }

    func testA315_expressivenessBulletShape() {
        let shaped = LLMRouterEscalator.expressivenessShape(["Point 315"], as: .list)
        XCTAssertTrue(shaped.hasPrefix("- "), "bullet shaping beats cloud-dependent formatting")
    }
}

final class A316RegressionTests: XCTestCase {
    func testA316_expressivenessTimelineShape() {
        let items = ["Event A 316", "Event B 316"]
        let shaped = QueryService.expressivenessShape(items, as: .timeline)
        XCTAssertTrue(shaped.contains("1. Event A 316"), "timeline shaping for offline synthesis")
        XCTAssertTrue(shaped.contains("2. Event B 316"))
    }

    func testA316_expressivenessBulletShape() {
        let shaped = QueryService.expressivenessShape(["Point 316"], as: .list)
        XCTAssertTrue(shaped.hasPrefix("- "), "bullet shaping beats cloud-dependent formatting")
    }
}

final class A317RegressionTests: XCTestCase {
    func testA317_expressivenessTimelineShape() {
        let items = ["Event A 317", "Event B 317"]
        let shaped = EngineClient.expressivenessShape(items, as: .timeline)
        XCTAssertTrue(shaped.contains("1. Event A 317"), "timeline shaping for offline synthesis")
        XCTAssertTrue(shaped.contains("2. Event B 317"))
    }

    func testA317_expressivenessBulletShape() {
        let shaped = EngineClient.expressivenessShape(["Point 317"], as: .list)
        XCTAssertTrue(shaped.hasPrefix("- "), "bullet shaping beats cloud-dependent formatting")
    }
}

final class A318RegressionTests: XCTestCase {
    func testA318_expressivenessTimelineShape() {
        let items = ["Event A 318", "Event B 318"]
        let shaped = ContainerCatalog.expressivenessShape(items, as: .timeline)
        XCTAssertTrue(shaped.contains("1. Event A 318"), "timeline shaping for offline synthesis")
        XCTAssertTrue(shaped.contains("2. Event B 318"))
    }

    func testA318_expressivenessBulletShape() {
        let shaped = ContainerCatalog.expressivenessShape(["Point 318"], as: .list)
        XCTAssertTrue(shaped.hasPrefix("- "), "bullet shaping beats cloud-dependent formatting")
    }
}

final class A319RegressionTests: XCTestCase {
    func testA319_expressivenessTimelineShape() {
        let items = ["Event A 319", "Event B 319"]
        let shaped = CitationVerifier.expressivenessShape(items, as: .timeline)
        XCTAssertTrue(shaped.contains("1. Event A 319"), "timeline shaping for offline synthesis")
        XCTAssertTrue(shaped.contains("2. Event B 319"))
    }

    func testA319_expressivenessBulletShape() {
        let shaped = CitationVerifier.expressivenessShape(["Point 319"], as: .list)
        XCTAssertTrue(shaped.hasPrefix("- "), "bullet shaping beats cloud-dependent formatting")
    }
}

final class A320RegressionTests: XCTestCase {
    func testA320_expressivenessTimelineShape() {
        let items = ["Event A 320", "Event B 320"]
        let shaped = SpanResolver.expressivenessShape(items, as: .timeline)
        XCTAssertTrue(shaped.contains("1. Event A 320"), "timeline shaping for offline synthesis")
        XCTAssertTrue(shaped.contains("2. Event B 320"))
    }

    func testA320_expressivenessBulletShape() {
        let shaped = SpanResolver.expressivenessShape(["Point 320"], as: .list)
        XCTAssertTrue(shaped.hasPrefix("- "), "bullet shaping beats cloud-dependent formatting")
    }
}

final class A321RegressionTests: XCTestCase {
    func testA321_schedulingYieldHintDefersUtility() {
        XCTAssertTrue(CharSpan.schedulingYieldHint(priority: .background),
                      "utility work must yield to interactive queries (M11)")
        XCTAssertFalse(CharSpan.schedulingYieldHint(priority: .interactive))
    }
}

final class A322RegressionTests: XCTestCase {
    func testA322_schedulingYieldHintDefersUtility() {
        XCTAssertTrue(AgenticGrep.schedulingYieldHint(priority: .background),
                      "utility work must yield to interactive queries (M11)")
        XCTAssertFalse(AgenticGrep.schedulingYieldHint(priority: .interactive))
    }
}

final class A323RegressionTests: XCTestCase {
    func testA323_schedulingYieldHintDefersUtility() {
        XCTAssertTrue(KeywordBackstop.schedulingYieldHint(priority: .background),
                      "utility work must yield to interactive queries (M11)")
        XCTAssertFalse(KeywordBackstop.schedulingYieldHint(priority: .interactive))
    }
}

final class A337RegressionTests: XCTestCase {
    func testA337_schedulingYieldHintDefersUtility() {
        XCTAssertTrue(ProfileDedupe.schedulingYieldHint(priority: .background),
                      "utility work must yield to interactive queries (M11)")
        XCTAssertFalse(ProfileDedupe.schedulingYieldHint(priority: .interactive))
    }
}

final class A338RegressionTests: XCTestCase {
    func testA338_schedulingYieldHintDefersUtility() {
        XCTAssertTrue(EgressGuard.schedulingYieldHint(priority: .background),
                      "utility work must yield to interactive queries (M11)")
        XCTAssertFalse(EgressGuard.schedulingYieldHint(priority: .interactive))
    }
}
final class A157RegressionTests: XCTestCase { func testA157_x() { XCTAssertEqual(MediaCompanion.unsupportedAnswerEvents(),[.state(.unsupportedAnswer)]) } }

final class A339RegressionTests: XCTestCase {
    func testA339_schedulingYieldHintDefersUtility() {
        XCTAssertTrue(WorkScheduler.schedulingYieldHint(priority: .background),
                      "utility work must yield to interactive queries (M11)")
        XCTAssertFalse(WorkScheduler.schedulingYieldHint(priority: .interactive))
    }
}

final class A340RegressionTests: XCTestCase {
    func testA340_schedulingYieldHintDefersUtility() {
        XCTAssertTrue(NotchReducer.schedulingYieldHint(priority: .background),
                      "utility work must yield to interactive queries (M11)")
        XCTAssertFalse(NotchReducer.schedulingYieldHint(priority: .interactive))
    }
}

final class A341RegressionTests: XCTestCase {
    func testA341_schedulingYieldHintDefersUtility() {
        XCTAssertTrue(LLMQueryRewriter.schedulingYieldHint(priority: .background),
                      "utility work must yield to interactive queries (M11)")
        XCTAssertFalse(LLMQueryRewriter.schedulingYieldHint(priority: .interactive))
    }
}

final class A342RegressionTests: XCTestCase {
    func testA342_schedulingYieldHintDefersUtility() {
        XCTAssertTrue(QueryDecomposer.schedulingYieldHint(priority: .background),
                      "utility work must yield to interactive queries (M11)")
        XCTAssertFalse(QueryDecomposer.schedulingYieldHint(priority: .interactive))
    }
}

final class A343RegressionTests: XCTestCase {
    func testA343_schedulingYieldHintDefersUtility() {
        XCTAssertTrue(ScopeClassifier.schedulingYieldHint(priority: .background),
                      "utility work must yield to interactive queries (M11)")
        XCTAssertFalse(ScopeClassifier.schedulingYieldHint(priority: .interactive))
    }
}

final class A344RegressionTests: XCTestCase {
    func testA344_schedulingYieldHintDefersUtility() {
        XCTAssertTrue(AdaptiveEffort.schedulingYieldHint(priority: .background),
                      "utility work must yield to interactive queries (M11)")
        XCTAssertFalse(AdaptiveEffort.schedulingYieldHint(priority: .interactive))
    }
}

final class A345RegressionTests: XCTestCase {
    func testA345_schedulingYieldHintDefersUtility() {
        XCTAssertTrue(AnswerCache.schedulingYieldHint(priority: .background),
                      "utility work must yield to interactive queries (M11)")
        XCTAssertFalse(AnswerCache.schedulingYieldHint(priority: .interactive))
    }
}

final class A347RegressionTests: XCTestCase {
    func testA347_schedulingYieldHintDefersUtility() {
        XCTAssertTrue(PersonalRanker.schedulingYieldHint(priority: .background),
                      "utility work must yield to interactive queries (M11)")
        XCTAssertFalse(PersonalRanker.schedulingYieldHint(priority: .interactive))
    }
}

final class A348RegressionTests: XCTestCase {
    func testA348_schedulingYieldHintDefersUtility() {
        XCTAssertTrue(NumericReasoner.schedulingYieldHint(priority: .background),
                      "utility work must yield to interactive queries (M11)")
        XCTAssertFalse(NumericReasoner.schedulingYieldHint(priority: .interactive))
    }
}

final class A349RegressionTests: XCTestCase {
    func testA349_schedulingYieldHintDefersUtility() {
        XCTAssertTrue(TimeWindow.schedulingYieldHint(priority: .background),
                      "utility work must yield to interactive queries (M11)")
        XCTAssertFalse(TimeWindow.schedulingYieldHint(priority: .interactive))
    }
}

final class A350RegressionTests: XCTestCase {
    func testA350_schedulingYieldHintDefersUtility() {
        XCTAssertTrue(TimelineBuilder.schedulingYieldHint(priority: .background),
                      "utility work must yield to interactive queries (M11)")
        XCTAssertFalse(TimelineBuilder.schedulingYieldHint(priority: .interactive))
    }
}
final class A186RegressionTests: XCTestCase { func testA186_x() { XCTAssertEqual(SyncEngine.indexingTerminalState(path:"/p"),.indexing(path:"/p")) } }

final class A244RegressionTests: XCTestCase {
    func testA244_dreamingDoesNotDuplicateSynthesis() {
        let existing = [MemoryEntry(id: "s244", memory: "Synthesis 244.", version: 1,
                                    isLatest: true, isForgotten: false, isStatic: false,
                                    parentMemoryId: nil, rootMemoryId: "s244",
                                    forgetAfter: nil, forgetReason: nil, history: [])]
        XCTAssertFalse(NumericReasoner.dreamingSafeSynthesis("Synthesis 244.", existing: existing,
                                                      constituents: ["fact 244"]),
                       "dreaming must not duplicate existing syntheses")
        XCTAssertTrue(NumericReasoner.dreamingSafeSynthesis("New synthesis 244.", existing: existing,
                                                     constituents: ["fact 244"]),
                      "novel synthesis with constituent grounding is allowed")
    }
}

final class A283RegressionTests: XCTestCase {
    func testA283_expressivenessTimelineShape() {
        let items = ["Event A 283", "Event B 283"]
        let shaped = LLMSynthesizer.expressivenessShape(items, as: .timeline)
        XCTAssertTrue(shaped.contains("1. Event A 283"), "timeline shaping for offline synthesis")
        XCTAssertTrue(shaped.contains("2. Event B 283"))
    }

    func testA283_expressivenessBulletShape() {
        let shaped = LLMSynthesizer.expressivenessShape(["Point 283"], as: .list)
        XCTAssertTrue(shaped.hasPrefix("- "), "bullet shaping beats cloud-dependent formatting")
    }
}

final class A284RegressionTests: XCTestCase {
    func testA284_expressivenessTimelineShape() {
        let items = ["Event A 284", "Event B 284"]
        let shaped = MemoryInspector.expressivenessShape(items, as: .timeline)
        XCTAssertTrue(shaped.contains("1. Event A 284"), "timeline shaping for offline synthesis")
        XCTAssertTrue(shaped.contains("2. Event B 284"))
    }

    func testA284_expressivenessBulletShape() {
        let shaped = MemoryInspector.expressivenessShape(["Point 284"], as: .list)
        XCTAssertTrue(shaped.hasPrefix("- "), "bullet shaping beats cloud-dependent formatting")
    }
}

final class A286RegressionTests: XCTestCase {
    func testA286_expressivenessTimelineShape() {
        let items = ["Event A 286", "Event B 286"]
        let shaped = EgressGuard.expressivenessShape(items, as: .timeline)
        XCTAssertTrue(shaped.contains("1. Event A 286"), "timeline shaping for offline synthesis")
        XCTAssertTrue(shaped.contains("2. Event B 286"))
    }

    func testA286_expressivenessBulletShape() {
        let shaped = EgressGuard.expressivenessShape(["Point 286"], as: .list)
        XCTAssertTrue(shaped.hasPrefix("- "), "bullet shaping beats cloud-dependent formatting")
    }
}

final class A287RegressionTests: XCTestCase {
    func testA287_expressivenessTimelineShape() {
        let items = ["Event A 287", "Event B 287"]
        let shaped = WorkScheduler.expressivenessShape(items, as: .timeline)
        XCTAssertTrue(shaped.contains("1. Event A 287"), "timeline shaping for offline synthesis")
        XCTAssertTrue(shaped.contains("2. Event B 287"))
    }

    func testA287_expressivenessBulletShape() {
        let shaped = WorkScheduler.expressivenessShape(["Point 287"], as: .list)
        XCTAssertTrue(shaped.hasPrefix("- "), "bullet shaping beats cloud-dependent formatting")
    }
}

final class A288RegressionTests: XCTestCase {
    func testA288_expressivenessTimelineShape() {
        let items = ["Event A 288", "Event B 288"]
        let shaped = NotchReducer.expressivenessShape(items, as: .timeline)
        XCTAssertTrue(shaped.contains("1. Event A 288"), "timeline shaping for offline synthesis")
        XCTAssertTrue(shaped.contains("2. Event B 288"))
    }

    func testA288_expressivenessBulletShape() {
        let shaped = NotchReducer.expressivenessShape(["Point 288"], as: .list)
        XCTAssertTrue(shaped.hasPrefix("- "), "bullet shaping beats cloud-dependent formatting")
    }
}

final class A289RegressionTests: XCTestCase {
    func testA289_expressivenessTimelineShape() {
        let items = ["Event A 289", "Event B 289"]
        let shaped = LLMQueryRewriter.expressivenessShape(items, as: .timeline)
        XCTAssertTrue(shaped.contains("1. Event A 289"), "timeline shaping for offline synthesis")
        XCTAssertTrue(shaped.contains("2. Event B 289"))
    }

    func testA289_expressivenessBulletShape() {
        let shaped = LLMQueryRewriter.expressivenessShape(["Point 289"], as: .list)
        XCTAssertTrue(shaped.hasPrefix("- "), "bullet shaping beats cloud-dependent formatting")
    }
}

final class A290RegressionTests: XCTestCase {
    func testA290_expressivenessTimelineShape() {
        let items = ["Event A 290", "Event B 290"]
        let shaped = QueryDecomposer.expressivenessShape(items, as: .timeline)
        XCTAssertTrue(shaped.contains("1. Event A 290"), "timeline shaping for offline synthesis")
        XCTAssertTrue(shaped.contains("2. Event B 290"))
    }

    func testA290_expressivenessBulletShape() {
        let shaped = QueryDecomposer.expressivenessShape(["Point 290"], as: .list)
        XCTAssertTrue(shaped.hasPrefix("- "), "bullet shaping beats cloud-dependent formatting")
    }
}

final class A291RegressionTests: XCTestCase {
    func testA291_expressivenessTimelineShape() {
        let items = ["Event A 291", "Event B 291"]
        let shaped = ScopeClassifier.expressivenessShape(items, as: .timeline)
        XCTAssertTrue(shaped.contains("1. Event A 291"), "timeline shaping for offline synthesis")
        XCTAssertTrue(shaped.contains("2. Event B 291"))
    }

    func testA291_expressivenessBulletShape() {
        let shaped = ScopeClassifier.expressivenessShape(["Point 291"], as: .list)
        XCTAssertTrue(shaped.hasPrefix("- "), "bullet shaping beats cloud-dependent formatting")
    }
}

final class A292RegressionTests: XCTestCase {
    func testA292_expressivenessTimelineShape() {
        let items = ["Event A 292", "Event B 292"]
        let shaped = AdaptiveEffort.expressivenessShape(items, as: .timeline)
        XCTAssertTrue(shaped.contains("1. Event A 292"), "timeline shaping for offline synthesis")
        XCTAssertTrue(shaped.contains("2. Event B 292"))
    }

    func testA292_expressivenessBulletShape() {
        let shaped = AdaptiveEffort.expressivenessShape(["Point 292"], as: .list)
        XCTAssertTrue(shaped.hasPrefix("- "), "bullet shaping beats cloud-dependent formatting")
    }
}

final class A302RegressionTests: XCTestCase {
    func testA302_expressivenessTimelineShape() {
        let items = ["Event A 302", "Event B 302"]
        let shaped = Provenance.expressivenessShape(items, as: .timeline)
        XCTAssertTrue(shaped.contains("1. Event A 302"), "timeline shaping for offline synthesis")
        XCTAssertTrue(shaped.contains("2. Event B 302"))
    }

    func testA302_expressivenessBulletShape() {
        let shaped = Provenance.expressivenessShape(["Point 302"], as: .list)
        XCTAssertTrue(shaped.hasPrefix("- "), "bullet shaping beats cloud-dependent formatting")
    }
}

final class A303RegressionTests: XCTestCase {
    func testA303_expressivenessTimelineShape() {
        let items = ["Event A 303", "Event B 303"]
        let shaped = CommandParser.expressivenessShape(items, as: .timeline)
        XCTAssertTrue(shaped.contains("1. Event A 303"), "timeline shaping for offline synthesis")
        XCTAssertTrue(shaped.contains("2. Event B 303"))
    }

    func testA303_expressivenessBulletShape() {
        let shaped = CommandParser.expressivenessShape(["Point 303"], as: .list)
        XCTAssertTrue(shaped.hasPrefix("- "), "bullet shaping beats cloud-dependent formatting")
    }
}

final class A324RegressionTests: XCTestCase {
    func testA324_schedulingYieldHintDefersUtility() {
        XCTAssertTrue(LLMHopPlanner.schedulingYieldHint(priority: .background),
                      "utility work must yield to interactive queries (M11)")
        XCTAssertFalse(LLMHopPlanner.schedulingYieldHint(priority: .interactive))
    }
}

final class A325RegressionTests: XCTestCase {
    func testA325_schedulingYieldHintDefersUtility() {
        XCTAssertTrue(ContextAssembler.schedulingYieldHint(priority: .background),
                      "utility work must yield to interactive queries (M11)")
        XCTAssertFalse(ContextAssembler.schedulingYieldHint(priority: .interactive))
    }
}

final class A326RegressionTests: XCTestCase {
    func testA326_schedulingYieldHintDefersUtility() {
        XCTAssertTrue(Prompt.schedulingYieldHint(priority: .background),
                      "utility work must yield to interactive queries (M11)")
        XCTAssertFalse(Prompt.schedulingYieldHint(priority: .interactive))
    }
}

final class A327RegressionTests: XCTestCase {
    func testA327_schedulingYieldHintDefersUtility() {
        XCTAssertTrue(OllamaClient.schedulingYieldHint(priority: .background),
                      "utility work must yield to interactive queries (M11)")
        XCTAssertFalse(OllamaClient.schedulingYieldHint(priority: .interactive))
    }
}

final class A328RegressionTests: XCTestCase {
    func testA328_schedulingYieldHintDefersUtility() {
        XCTAssertTrue(ItemState.schedulingYieldHint(priority: .background),
                      "utility work must yield to interactive queries (M11)")
        XCTAssertFalse(ItemState.schedulingYieldHint(priority: .interactive))
    }
}

final class A329RegressionTests: XCTestCase {
    func testA329_schedulingYieldHintDefersUtility() {
        XCTAssertTrue(IngestGate.schedulingYieldHint(priority: .background),
                      "utility work must yield to interactive queries (M11)")
        XCTAssertFalse(IngestGate.schedulingYieldHint(priority: .interactive))
    }
}

final class A330RegressionTests: XCTestCase {
    func testA330_schedulingYieldHintDefersUtility() {
        XCTAssertTrue(SyncEngine.schedulingYieldHint(priority: .background),
                      "utility work must yield to interactive queries (M11)")
        XCTAssertFalse(SyncEngine.schedulingYieldHint(priority: .interactive))
    }
}

final class A331RegressionTests: XCTestCase {
    func testA331_schedulingYieldHintDefersUtility() {
        XCTAssertTrue(ContentHash.schedulingYieldHint(priority: .background),
                      "utility work must yield to interactive queries (M11)")
        XCTAssertFalse(ContentHash.schedulingYieldHint(priority: .interactive))
    }
}

final class A332RegressionTests: XCTestCase {
    func testA332_schedulingYieldHintDefersUtility() {
        XCTAssertTrue(MemoryDynamics.schedulingYieldHint(priority: .background),
                      "utility work must yield to interactive queries (M11)")
        XCTAssertFalse(MemoryDynamics.schedulingYieldHint(priority: .interactive))
    }
}

final class A333RegressionTests: XCTestCase {
    func testA333_schedulingYieldHintDefersUtility() {
        XCTAssertTrue(ConflictDetector.schedulingYieldHint(priority: .background),
                      "utility work must yield to interactive queries (M11)")
        XCTAssertFalse(ConflictDetector.schedulingYieldHint(priority: .interactive))
    }
}

final class A334RegressionTests: XCTestCase {
    func testA334_schedulingYieldHintDefersUtility() {
        XCTAssertTrue(ColdArchive.schedulingYieldHint(priority: .background),
                      "utility work must yield to interactive queries (M11)")
        XCTAssertFalse(ColdArchive.schedulingYieldHint(priority: .interactive))
    }
}

final class A335RegressionTests: XCTestCase {
    func testA335_schedulingYieldHintDefersUtility() {
        XCTAssertTrue(LLMSynthesizer.schedulingYieldHint(priority: .background),
                      "utility work must yield to interactive queries (M11)")
        XCTAssertFalse(LLMSynthesizer.schedulingYieldHint(priority: .interactive))
    }
}

final class A336RegressionTests: XCTestCase {
    func testA336_schedulingYieldHintDefersUtility() {
        XCTAssertTrue(MemoryInspector.schedulingYieldHint(priority: .background),
                      "utility work must yield to interactive queries (M11)")
        XCTAssertFalse(MemoryInspector.schedulingYieldHint(priority: .interactive))
    }
}

final class A346RegressionTests: XCTestCase {
    func testA346_schedulingYieldHintDefersUtility() {
        XCTAssertTrue(QueryHistory.schedulingYieldHint(priority: .background),
                      "utility work must yield to interactive queries (M11)")
        XCTAssertFalse(QueryHistory.schedulingYieldHint(priority: .interactive))
    }
}
final class A128RegressionTests: XCTestCase { func testA128_x() { XCTAssertEqual(ItemState.unsupportedAnswerEvents(),[.state(.unsupportedAnswer)]) } }

final class A99RegressionTests: XCTestCase {
    func testA99_lifecycleEventsRenderable() {
        let events = Digest.lifecycleEvents(branch: .emptyEvidence)
        XCTAssertFalse(events.isEmpty)
        var state = NotchState(phase: .input, query: "q99", answer: "", sources: [])
        for e in events { state = NotchReducer.apply(e, to: state) }
        XCTAssertTrue(!state.answer.isEmpty || state.terminal != nil || !state.reasoning.isEmpty || state.phase == .searching)
    }
}

/// A-041: source-less syntheses and static facts survive orphan GC.
final class SelfHealExemptionTests: XCTestCase {
    func testSourcelessStaticAndSynthesisExempt() {
        let memories = [
            MemoryEntry(id: "static", memory: "Manual fact.", version: 1, isLatest: true, isForgotten: false,
                        isStatic: true, parentMemoryId: nil, rootMemoryId: "static",
                        forgetAfter: nil, forgetReason: nil, history: [], documentIds: []),
            MemoryEntry(id: "syn", memory: "Synthesis.", version: 1, isLatest: true, isForgotten: false,
                        isStatic: false, parentMemoryId: "p", rootMemoryId: "syn",
                        forgetAfter: nil, forgetReason: nil, history: [], documentIds: []),
            MemoryEntry(id: "orphan", memory: "gone", version: 1, isLatest: true, isForgotten: false,
                        isStatic: false, parentMemoryId: nil, rootMemoryId: "orphan",
                        forgetAfter: nil, forgetReason: nil, history: [], documentIds: []),
        ]
        XCTAssertEqual(SelfHeal.orphanedMemoryIds(memories: memories, liveDocIds: []), ["orphan"])
    }
}

/// A-041: source-less syntheses and static facts survive orphan GC.
final class SelfHealExemptionTests: XCTestCase {
    func testSourcelessStaticAndSynthesisExempt() {
        let memories = [
            MemoryEntry(id: "static", memory: "Manual fact.", version: 1, isLatest: true, isForgotten: false,
                        isStatic: true, parentMemoryId: nil, rootMemoryId: "static",
                        forgetAfter: nil, forgetReason: nil, history: [], documentIds: []),
            MemoryEntry(id: "syn", memory: "Synthesis.", version: 1, isLatest: true, isForgotten: false,
                        isStatic: false, parentMemoryId: "p", rootMemoryId: "syn",
                        forgetAfter: nil, forgetReason: nil, history: [], documentIds: []),
            MemoryEntry(id: "orphan", memory: "gone", version: 1, isLatest: true, isForgotten: false,
                        isStatic: false, parentMemoryId: nil, rootMemoryId: "orphan",
                        forgetAfter: nil, forgetReason: nil, history: [], documentIds: []),
        ]
        XCTAssertEqual(SelfHeal.orphanedMemoryIds(memories: memories, liveDocIds: []), ["orphan"])
    }
}
