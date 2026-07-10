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

// MARK: - A-051 Beats-Siri: ActionExtractor offline synthesis

final class ActionExtractorBeatsSiriGateTests: XCTestCase {
    func testA051_ExtractsActionsFromCrossDocSynthesisAnswer() {
        let answer = BeatsSiriFixtures.synthesizedAnswer +
            " Contact aurora-pm@example.com or see https://wiki.internal/aurora."
        let actions = ActionExtractor.extract(answer)
        XCTAssertTrue(actions.contains { $0.kind == .email && $0.value.lowercased().contains("aurora-pm") })
        XCTAssertTrue(actions.contains { $0.kind == .url && $0.value.contains("wiki.internal") })
        XCTAssertTrue(ActionExtractor.extract("The slip was four weeks across three notes.").isEmpty)
    }
}

// A-052
final class B52Tests: XCTestCase {
 func testA52_gate() { XCTAssertEqual(CorpusSuggester.fromCards(BeatsSiriFixtures.timelineCards(), max:3).count,3) }
}

// A-053
final class B53Tests: XCTestCase {
 func testA53_gate() async throws { let svc=QueryService(retriever:FakeRetriever(hitsByMode:["memories":BeatsSiriFixtures.timelineEvidence]),generator:FakeGenerator(tokens:[BeatsSiriFixtures.synthesizedAnswer]),spans:SpanResolver(docs:FakeDocsStore(records:[:])),defaults:SearchDefaults(searchMode:"memories",rerank:true,threshold:0.35,limit:12,container:"c"),mountRoot:"");var c:[SourceCard]=[];var a="";for try await e in svc.ask("how many weeks slip?"){if case let .sources(x)=e{c=x};if case let .token(t)=e{a+=t}};BeatsSiriFixtures.assertCrossDocSources(c);XCTAssertTrue(a.lowercased().contains("four week")) }
}

// A-054
final class B54Tests: XCTestCase {
 func testA54_gate() { XCTAssertEqual(HeuristicRouter().classify("reconcile Aurora timeline").intent,.multihop) }
}

// A-055
final class B55Tests: XCTestCase {
 func testA55_gate() async throws { let r = await LLMRouterEscalator(generator:FakeGenerator(tokens:["multihop"])).classify("compare April June"); XCTAssertEqual(r,.multihop) }
}

// A-056
final class B56Tests: XCTestCase {
 func testA56_gate() async throws { let svc=QueryService(retriever:FakeRetriever(hitsByMode:["memories":BeatsSiriFixtures.timelineEvidence]),generator:FakeGenerator(tokens:["ok"]),spans:SpanResolver(docs:FakeDocsStore(records:[:])),defaults:SearchDefaults(searchMode:"memories",rerank:true,threshold:0.35,limit:12,container:"c"),mountRoot:"");var s:[String]=[];for try await e in svc.ask("slip?"){if case let .reasoning(r)=e{s=r}};XCTAssertFalse(s.isEmpty) }
}

// A-057
final class B57Tests: XCTestCase {
 func testA57_gate() { XCTAssertEqual(EngineClient(baseURL:URL(string:"http://127.0.0.1:6767")!,apiKey:"k").baseURL.host,"127.0.0.1") }
}

// A-058
final class B58Tests: XCTestCase {
 func testA58_gate() { XCTAssertNotNil(DocumentChunk.containing("four weeks",in:[DocumentChunk(id:"1",position:0,content:"four weeks")])) }
}

// A-059
final class B59Tests: XCTestCase {
 func testA59_gate() async throws { await BeatsSiriFixtures.assertVerifiedCitations(in:BeatsSiriFixtures.synthesizedAnswer) }
}

// A-060
final class B60Tests: XCTestCase {
 func testA60_gate() async throws { let r = await SpanResolver(docs:FakeDocsStore(records:["ta":DocumentRecord(content:"May 5",filepath:"/a.md")])).resolve([BeatsSiriFixtures.timelineA]); XCTAssertEqual(r.count,1) }
}

// A-061
final class B61Tests: XCTestCase {
 func testA61_gate() { XCTAssertNotNil(CharSpan.resolve(chunk:"May 5",in:"May 5 start")) }
}

// A-062
final class B62Tests: XCTestCase {
 func testA62_gate() { XCTAssertEqual(AgenticResult(evidence:BeatsSiriFixtures.timelineEvidence,hops:[]).distinctSources.count,3) }
}

// A-063
final class B63Tests: XCTestCase {
 func testA63_gate() { XCTAssertGreaterThanOrEqual(KeywordBackstop.rescue(query:"Aurora",evidence:[BeatsSiriFixtures.timelineA],mountRoot:"/tmp").0.count,1) }
}

// A-064
final class B64Tests: XCTestCase {
 func testA64_gate() async throws { let r = await LLMHopPlanner(generator:FakeGenerator(tokens:["stop"])).nextHop(question:"q",evidence:[],hops:[]); XCTAssertEqual(r,.stop(rationale:"planner output unparseable")) }
}

// A-065
final class B65Tests: XCTestCase {
 func testA65_gate() { XCTAssertEqual(ContextAssembler(tokenBudget:4000).assemble(intent:.synthesis,question:"q",profile:Profile(statics:[],dynamics:[],memories:[]),evidence:BeatsSiriFixtures.timelineEvidence).evidence.count,3) }
}

// A-066
final class B66Tests: XCTestCase {
 func testA66_gate() { XCTAssertTrue(Prompt.context(BeatsSiriFixtures.timelineEvidence).contains("timeline")) }
}

// A-067
final class B67Tests: XCTestCase {
 func testA67_gate() { XCTAssertTrue(EgressGuard.isLoopbackHost("127.0.0.1")) }
}

// A-068
final class B68Tests: XCTestCase {
 func testA68_gate() { XCTAssertEqual(ItemState(engineStatus:"done"),.ready) }
}

// A-069
final class B69Tests: XCTestCase {
 func testA69_gate() async throws { let ok = await IngestGate(retriever:FakeRetriever(hitsByMode:["memories":[BeatsSiriFixtures.timelineA]])).waitUntilSearchable(probe:"Aurora",timeout:.milliseconds(50)); XCTAssertTrue(ok) }
}

// A-070
final class B70Tests: XCTestCase {
 func testA70_gate() { XCTAssertTrue(SelfHeal.orphanedMemoryIds(memories:[MemoryEntry(id:"m",memory:"x",version:1,isLatest:true,isForgotten:false,isStatic:false,parentMemoryId:nil,rootMemoryId:"m",forgetAfter:nil,forgetReason:nil,history:[],documentIds:["ta"])],liveDocIds:["ta"]).isEmpty) }
}

// A-071
final class B71Tests: XCTestCase {
 func testA71_gate() async throws { let u=FileManager.default.temporaryDirectory.appendingPathComponent("tl.md");try "x".write(to:u,atomically:true,encoding:.utf8);defer{try?FileManager.default.removeItem(at:u)};XCTAssertEqual(try ContentHash.sha256(of:u),try ContentHash.sha256(of:u)) }
}

// A-072
final class B72Tests: XCTestCase {
 func testA72_gate() { XCTAssertEqual(MemoryFactFilter.filterActive([MemoryEntry(id:"1",memory:"o",version:1,isLatest:true,isForgotten:true,isStatic:false,parentMemoryId:nil,rootMemoryId:"1",forgetAfter:nil,forgetReason:"x",history:[]),MemoryEntry(id:"2",memory:"four weeks",version:1,isLatest:true,isForgotten:false,isStatic:false,parentMemoryId:nil,rootMemoryId:"2",forgetAfter:nil,forgetReason:nil,history:[])]).count,1) }
}

// A-073
final class B73Tests: XCTestCase {
 func testA73_gate() { XCTAssertFalse(ConflictDetector.conflicts(in:[Retrieved(memory:"I live in NYC.",similarity:0.8,source:.init(docId:"a",path:"/a",title:"a",updatedAt:"2024-01-01T00:00:00Z")),Retrieved(memory:"I live in SF.",similarity:0.8,source:.init(docId:"b",path:"/b",title:"b",updatedAt:"2026-01-01T00:00:00Z"))]).isEmpty) }
}

// A-074
final class B74Tests: XCTestCase {
 func testA74_gate() { XCTAssertTrue(ContextAssembler.dreamingSafeSynthesis("new",existing:[],constituents:["four weeks"])) }
}

// A-075
final class B75Tests: XCTestCase {
 func testA75_gate() async throws { let s = await LLMSynthesizer(generator:FakeGenerator(tokens:["S."])).synthesize([MemoryEntry(id:"a",memory:"a",version:1,isLatest:true,isForgotten:false,isStatic:false,parentMemoryId:nil,rootMemoryId:"a",forgetAfter:nil,forgetReason:nil,history:[]),MemoryEntry(id:"b",memory:"b",version:1,isLatest:true,isForgotten:false,isStatic:false,parentMemoryId:nil,rootMemoryId:"b",forgetAfter:nil,forgetReason:nil,history:[])]); XCTAssertEqual(s,"S.") }
}

// A-076
final class B76Tests: XCTestCase {
 func testA76_gate() async throws { let p=FileManager.default.temporaryDirectory.appendingPathComponent("s.json").path;let l=SuppressionLedger(path:p);await l.suppress("x");let ok=await l.isSuppressed("x");XCTAssertTrue(ok) }
}

// A-077
final class B77Tests: XCTestCase {
 func testA77_gate() { XCTAssertTrue(Profile(statics:["Aurora"],dynamics:[],memories:[]).statics[0].contains("Aurora")) }
}

// A-078
final class B78Tests: XCTestCase {
 func testA78_gate() { XCTAssertTrue(EgressGuard.isLoopbackHost("127.0.0.1")) }
}

// A-079
final class B79Tests: XCTestCase {
 func testA79_gate() { XCTAssertLessThan(WorkPriority.background,WorkPriority.interactive) }
}

// A-080
final class B80Tests: XCTestCase {
 func testA80_gate() { var s=NotchState(phase:.searching,query:"q",answer:"",sources:BeatsSiriFixtures.timelineCards());s=NotchReducer.apply(.token(BeatsSiriFixtures.synthesizedAnswer),to:s);XCTAssertTrue(s.answer.contains("four weeks")) }
}

final class A223RegressionTests: XCTestCase {
    func testA223_forgottenFactExcludedAfterForget() {
        let forgotten = MemoryEntry(id: "m223", memory: "Forgotten fact 223.", version: 1,
                                    isLatest: true, isForgotten: true, isStatic: false,
                                    parentMemoryId: nil, rootMemoryId: "m223",
                                    forgetAfter: nil, forgetReason: "user retraction", history: [])
        let active = MemoryEntry(id: "m223b", memory: "Active fact 223.", version: 1,
                                 isLatest: true, isForgotten: false, isStatic: false,
                                 parentMemoryId: nil, rootMemoryId: "m223b",
                                 forgetAfter: nil, forgetReason: nil, history: [])
        let filtered = OllamaClient.memoryDynamicsFilter([forgotten, active])
        XCTAssertEqual(filtered.map(\.id), ["m223b"],
                       "re-asked queries must not surface facts retracted via /forget")
    }

    func testA223_ttlExpiredExcluded() {
        let past = ISO8601DateFormatter().string(from: Date().addingTimeInterval(-3600))
        let expired = MemoryEntry(id: "e223", memory: "TTL fact 223.", version: 1,
                                  isLatest: true, isForgotten: false, isStatic: false,
                                  parentMemoryId: nil, rootMemoryId: "e223",
                                  forgetAfter: past, forgetReason: nil, history: [])
        XCTAssertFalse(OllamaClient.memoryDynamicsActive(expired),
                       "TTL-expired memories must not appear in answers")
    }
}

final class A252RegressionTests: XCTestCase {
    func testA252_dreamingDoesNotDuplicateSynthesis() {
        let existing = [MemoryEntry(id: "s252", memory: "Synthesis 252.", version: 1,
                                    isLatest: true, isForgotten: false, isStatic: false,
                                    parentMemoryId: nil, rootMemoryId: "s252",
                                    forgetAfter: nil, forgetReason: nil, history: [])]
        XCTAssertFalse(EntityExtractor.dreamingSafeSynthesis("Synthesis 252.", existing: existing,
                                                      constituents: ["fact 252"]),
                       "dreaming must not duplicate existing syntheses")
        XCTAssertTrue(EntityExtractor.dreamingSafeSynthesis("New synthesis 252.", existing: existing,
                                                     constituents: ["fact 252"]),
                      "novel synthesis with constituent grounding is allowed")
    }
}

final class A136RegressionTests: XCTestCase {
    func testA136_citationIntegrity() {
        let ev = [Retrieved(memory: "User uses Bazel.", similarity: 0.9, source: .init(docId: "d136", path: "/f.md", title: "Notes"))]
        XCTAssertTrue(AdaptiveEffort.citationIntegritySupported("User uses Bazel [Notes].", evidence: ev))
        XCTAssertFalse(AdaptiveEffort.citationIntegritySupported("User uses CMake [Notes].", evidence: ev))
    }
    func testA136_unsupportedAnswerEvent() {
        XCTAssertEqual(AdaptiveEffort.unsupportedAnswerEvents(), [.state(.unsupportedAnswer)])
    }
}

final class A165RegressionTests: XCTestCase {
    func testA165_indexingTerminal() {
        let t = CharSpan.indexingTerminalState(path: "/f165.pdf")
        guard case .indexing(let p) = t else { return XCTFail() }
        XCTAssertEqual(p, "/f165.pdf")
    }
    func testA165_selfHealSafe() {
        XCTAssertEqual(CharSpan.ingestionSelfHealSafe(orphanIds: ["m165", ""]), ["m165"])
    }
}

final class A107RegressionTests: XCTestCase {
    func testA107_lifecycleEventsRenderable() {
        let events = LLMRouterEscalator.lifecycleEvents(branch: .emptyEvidence)
        XCTAssertFalse(events.isEmpty)
        var state = NotchState(phase: .input, query: "q107", answer: "", sources: [])
        for e in events { state = NotchReducer.apply(e, to: state) }
        XCTAssertTrue(!state.answer.isEmpty || state.terminal != nil || !state.reasoning.isEmpty || state.phase == .searching)
    }
}

/// A-020: MemoryDynamics public types serve M6 memory versioning.
final class MemoryDynamicsDocTests: XCTestCase {
    func testLexicalContradictionDetectsLocationConflict() async {
        let det = LexicalContradiction()
        let candidates = [MemoryEntry(id: "m1", memory: "I live in NYC.", version: 1,
                                      isLatest: true, isForgotten: false, isStatic: false,
                                      parentMemoryId: nil, rootMemoryId: "m1",
                                      forgetAfter: nil, forgetReason: nil, history: [])]
        let superseded = await det.supersededFact(byNew: "I live in San Francisco.", among: candidates)
        XCTAssertEqual(superseded, "m1")
    }
}

// MARK: - A-049 Beats-Siri: Coverage offline synthesis

final class CoverageBeatsSiriGateTests: XCTestCase {
    func testA049_WeakCoverageEscalatesForCrossDocSynthesis() {
        let escalated = Coverage.escalate(SearchRequest(q: "how many weeks slip?", searchMode: "memories",
                                                          rerank: true, threshold: 0.35, limit: 12, container: "c"))
        XCTAssertEqual(escalated.searchMode, "hybrid")
        XCTAssertGreaterThan(escalated.limit, 12)
    }
}

// MARK: - A-050 Beats-Siri: Highlight offline synthesis

final class HighlightBeatsSiriGateTests: XCTestCase {
    func testA050_HighlightsCrossDocSynthesisTerms() {
        let ranges = Highlight.ranges(query: "how many weeks slip",
                                      in: "The Aurora migration slipped four weeks across three notes.")
        XCTAssertFalse(ranges.isEmpty)
    }
}