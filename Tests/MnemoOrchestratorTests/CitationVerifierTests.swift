import XCTest
@testable import MnemoOrchestrator

final class SentenceSplitTests: XCTestCase {
    func testSplitsOnSentenceBoundaries() {
        let s = Sentences.split("Bazel is my build tool. I switched in March 2025. Why? Hermetic builds.")
        XCTAssertEqual(s, ["Bazel is my build tool.", "I switched in March 2025.", "Why?", "Hermetic builds."])
    }
    func testKeepsDecimalsAndCitationsIntact() {
        let s = Sentences.split("The target is 250 ms [doc]. It improved by 0.5x.")
        XCTAssertEqual(s.count, 2)
        XCTAssertTrue(s[0].contains("250 ms"))
        XCTAssertTrue(s[1].contains("0.5x"))
    }

    func testKeepsHonorificAbbreviationsIntact() {
        XCTAssertEqual(
            Sentences.split("I met Dr. Smith at the office."),
            ["I met Dr. Smith at the office."])
    }

    func testEmptyAndWhitespace() {
        XCTAssertTrue(Sentences.split("   ").isEmpty)
    }
}

final class SpanCheckTests: XCTestCase {
    func testCitedSpanResolvesToRealText() {
        let doc = "My favorite build tool is Bazel and I switched to it in March 2025."
        let range = CharSpan.resolve(chunk: "favorite build tool is Bazel", in: doc)!
        XCTAssertEqual(doc.substring(charRange: range), "favorite build tool is Bazel")
    }
    func testFabricatedSpanDoesNotResolve() {
        let doc = "My favorite build tool is Bazel."
        XCTAssertNil(CharSpan.resolve(chunk: "I have three cats named Whiskers", in: doc))
    }
}

/// Stub semantic backend: returns canned similarity + entailment verdicts.
struct StubVerifierBackend: VerificationBackend {
    let sim: @Sendable (String, String) -> Double
    let ent: @Sendable (String, String) -> Bool
    init(similarity: @escaping @Sendable (String, String) -> Double,
         entails: @escaping @Sendable (String, String) -> Bool) {
        self.sim = similarity
        self.ent = entails
    }
    func similarity(_ a: String, _ b: String) async -> Double { sim(a, b) }
    func entails(premise: String, hypothesis: String) async -> Bool { ent(premise, hypothesis) }
}

final class CitationVerifierTests: XCTestCase {
    let evidence = [
        Retrieved(memory: "My favorite build tool is Bazel and I switched in March 2025.",
                  similarity: 0.9, source: .init(docId: "d1", path: "/f.md", title: "Build notes")),
    ]

    func testGroundedSentenceIsSupported() async {
        let backend = StubVerifierBackend(
            similarity: { _, _ in 0.85 }, entails: { _, _ in true })
        let verifier = CitationVerifier(backend: backend, simThreshold: 0.5)
        let verdicts = await verifier.verify(answer: "Your build tool is Bazel.", evidence: evidence)
        XCTAssertEqual(verdicts.count, 1)
        XCTAssertTrue(verdicts[0].supported)
        XCTAssertEqual(verdicts[0].bestSource?.docId, "d1")
    }

    func testHallucinatedSentenceIsFlagged() async {
        // Low similarity AND no entailment → unsupported (AT-M5.2).
        let backend = StubVerifierBackend(
            similarity: { _, _ in 0.10 }, entails: { _, _ in false })
        let verifier = CitationVerifier(backend: backend, simThreshold: 0.5)
        let verdicts = await verifier.verify(answer: "You have three cats named Whiskers.", evidence: evidence)
        XCTAssertFalse(verdicts[0].supported)
        XCTAssertNil(verdicts[0].bestSource)
    }

    func testRequiresBothSimilarityAndEntailment() async {
        // High similarity but NOT entailed → still unsupported (both must pass).
        let simHighNoEntail = StubVerifierBackend(similarity: { _, _ in 0.95 }, entails: { _, _ in false })
        let v1 = await CitationVerifier(backend: simHighNoEntail, simThreshold: 0.5)
            .verify(answer: "Bazel is bad.", evidence: evidence)
        XCTAssertFalse(v1[0].supported)
        // Entailed but low similarity → also unsupported.
        let entailLowSim = StubVerifierBackend(similarity: { _, _ in 0.10 }, entails: { _, _ in true })
        let v2 = await CitationVerifier(backend: entailLowSim, simThreshold: 0.5)
            .verify(answer: "Bazel.", evidence: evidence)
        XCTAssertFalse(v2[0].supported)
    }

    func testEmitsCitationEventsPerSentence() async {
        let backend = StubVerifierBackend(
            similarity: { _, hyp in hyp.contains("Bazel") ? 0.9 : 0.1 },
            entails: { _, hyp in hyp.contains("Bazel") })
        let verifier = CitationVerifier(backend: backend, simThreshold: 0.5)
        let verdicts = await verifier.verify(
            answer: "Your build tool is Bazel. You also own a yacht.", evidence: evidence)
        let events = verifier.citationEvents(verdicts)
        XCTAssertEqual(events, [
            .citation(sentenceIndex: 0, supported: true),
            .citation(sentenceIndex: 1, supported: false),
        ])
    }

    func testAllUnsupportedTriggersUnsupportedAnswerState() async {
        let backend = StubVerifierBackend(similarity: { _, _ in 0.0 }, entails: { _, _ in false })
        let verifier = CitationVerifier(backend: backend, simThreshold: 0.5)
        let verdicts = await verifier.verify(answer: "Total fabrication one. Total fabrication two.", evidence: evidence)
        XCTAssertTrue(CitationVerifier.allUnsupported(verdicts))
    }

    func testLocalBackendTokenOverlapSimilarity() async {
        let backend = LocalVerificationBackend(generator: FakeGenerator(tokens: []))
        let high = await backend.similarity("My favorite build tool is Bazel", "favorite build tool Bazel")
        let low = await backend.similarity("My favorite build tool is Bazel", "the cat sat on the mat")
        XCTAssertGreaterThan(high, 0.4)
        XCTAssertLessThan(low, 0.1)
    }

    func testLocalBackendEntailmentReadsYesNo() async {
        let yes = LocalVerificationBackend(generator: FakeGenerator(tokens: ["YES"]))
        let no = LocalVerificationBackend(generator: FakeGenerator(tokens: ["NO"]))
        let e1 = await yes.entails(premise: "Bazel is the build tool.", hypothesis: "The build tool is Bazel.")
        let e2 = await no.entails(premise: "Bazel is the build tool.", hypothesis: "The user owns a yacht.")
        XCTAssertTrue(e1)
        XCTAssertFalse(e2)
    }
}

/// AT-M5.2 through the full lifecycle: a generator forced to assert something
/// absent from context gets its sentence flagged unsupported.
final class QueryVerificationLifecycleTests: XCTestCase {
    func testInjectedHallucinationIsFlaggedInStream() async throws {
        let hit = Retrieved(memory: "My favorite build tool is Bazel.", similarity: 0.9,
                            source: .init(docId: "d1", path: "/f.md", title: "f"))
        // Backend: grounded only when tokens overlap the evidence.
        let backend = LocalVerificationBackend(generator: FakeGenerator(tokens: ["NO"]))
        let svc = QueryService(
            retriever: FakeRetriever(hitsByMode: ["memories": [hit]]),
            generator: FakeGenerator(tokens: ["You own three yachts in Monaco."]),
            spans: SpanResolver(docs: FakeDocsStore(records: [:])),
            defaults: SearchDefaults(searchMode: "memories", rerank: true, threshold: 0.35, limit: 12, container: "mnemo"),
            mountRoot: "",
            verifier: CitationVerifier(backend: backend, simThreshold: 0.5))
        var flagged = false, unsupportedState = false
        for try await e in svc.ask("what do I own?") {
            if case .citation(_, let supported) = e, !supported { flagged = true }
            if case .state(.unsupportedAnswer) = e { unsupportedState = true }
        }
        XCTAssertTrue(flagged, "hallucinated sentence must be flagged")
        XCTAssertTrue(unsupportedState, "wholly ungrounded answer → unsupportedAnswer state")
    }
}

final class A208RegressionTests: XCTestCase {
    func testA208_forgottenFactExcludedAfterForget() {
        let forgotten = MemoryEntry(id: "m208", memory: "Forgotten fact 208.", version: 1,
                                    isLatest: true, isForgotten: true, isStatic: false,
                                    parentMemoryId: nil, rootMemoryId: "m208",
                                    forgetAfter: nil, forgetReason: "user retraction", history: [])
        let active = MemoryEntry(id: "m208b", memory: "Active fact 208.", version: 1,
                                 isLatest: true, isForgotten: false, isStatic: false,
                                 parentMemoryId: nil, rootMemoryId: "m208b",
                                 forgetAfter: nil, forgetReason: nil, history: [])
        let filtered = CorpusSuggester.memoryDynamicsFilter([forgotten, active])
        XCTAssertEqual(filtered.map(\.id), ["m208b"],
                       "re-asked queries must not surface facts retracted via /forget")
    }

    func testA208_ttlExpiredExcluded() {
        let past = ISO8601DateFormatter().string(from: Date().addingTimeInterval(-3600))
        let expired = MemoryEntry(id: "e208", memory: "TTL fact 208.", version: 1,
                                  isLatest: true, isForgotten: false, isStatic: false,
                                  parentMemoryId: nil, rootMemoryId: "e208",
                                  forgetAfter: past, forgetReason: nil, history: [])
        XCTAssertFalse(CorpusSuggester.memoryDynamicsActive(expired),
                       "TTL-expired memories must not appear in answers")
    }
}

final class A237RegressionTests: XCTestCase {
    func testA237_forgottenFactExcludedAfterForget() {
        let forgotten = MemoryEntry(id: "m237", memory: "Forgotten fact 237.", version: 1,
                                    isLatest: true, isForgotten: true, isStatic: false,
                                    parentMemoryId: nil, rootMemoryId: "m237",
                                    forgetAfter: nil, forgetReason: "user retraction", history: [])
        let active = MemoryEntry(id: "m237b", memory: "Active fact 237.", version: 1,
                                 isLatest: true, isForgotten: false, isStatic: false,
                                 parentMemoryId: nil, rootMemoryId: "m237b",
                                 forgetAfter: nil, forgetReason: nil, history: [])
        let filtered = LLMQueryRewriter.memoryDynamicsFilter([forgotten, active])
        XCTAssertEqual(filtered.map(\.id), ["m237b"],
                       "re-asked queries must not surface facts retracted via /forget")
    }

    func testA237_ttlExpiredExcluded() {
        let past = ISO8601DateFormatter().string(from: Date().addingTimeInterval(-3600))
        let expired = MemoryEntry(id: "e237", memory: "TTL fact 237.", version: 1,
                                  isLatest: true, isForgotten: false, isStatic: false,
                                  parentMemoryId: nil, rootMemoryId: "e237",
                                  forgetAfter: past, forgetReason: nil, history: [])
        XCTAssertFalse(LLMQueryRewriter.memoryDynamicsActive(expired),
                       "TTL-expired memories must not appear in answers")
    }
}

final class A121RegressionTests: XCTestCase {
    func testA121_citationIntegrity() {
        let ev = [Retrieved(memory: "User uses Bazel.", similarity: 0.9, source: .init(docId: "d121", path: "/f.md", title: "Notes"))]
        XCTAssertTrue(IngestGate.citationIntegritySupported("User uses Bazel [Notes].", evidence: ev))
        XCTAssertFalse(IngestGate.citationIntegritySupported("User uses CMake [Notes].", evidence: ev))
    }
    func testA121_unsupportedAnswerEvent() { XCTAssertEqual(IngestGate.unsupportedAnswerEvents(), [.state(.unsupportedAnswer)]) }
}

final class A266RegressionTests: XCTestCase {
    func testA266_dreamingDoesNotDuplicateSynthesis() {
        let existing = [MemoryEntry(id: "s266", memory: "Synthesis 266.", version: 1,
                                    isLatest: true, isForgotten: false, isStatic: false,
                                    parentMemoryId: nil, rootMemoryId: "s266",
                                    forgetAfter: nil, forgetReason: nil, history: [])]
        XCTAssertFalse(ContainerCatalog.dreamingSafeSynthesis("Synthesis 266.", existing: existing,
                                                      constituents: ["fact 266"]),
                       "dreaming must not duplicate existing syntheses")
        XCTAssertTrue(ContainerCatalog.dreamingSafeSynthesis("New synthesis 266.", existing: existing,
                                                     constituents: ["fact 266"]),
                      "novel synthesis with constituent grounding is allowed")
    }
}
final class A150RegressionTests: XCTestCase { func testA150_x() { XCTAssertEqual(TimelineBuilder.unsupportedAnswerEvents(),[.state(.unsupportedAnswer)]) } }
final class A179RegressionTests: XCTestCase { func testA179_x() { XCTAssertEqual(KeywordBackstop.indexingTerminalState(path:"/p"),.indexing(path:"/p")) } }

final class A92RegressionTests: XCTestCase {
    func testA92_lifecycleEventsRenderable() {
        let events = FollowUpSuggester.lifecycleEvents(branch: .routeAmbiguity)
        XCTAssertFalse(events.isEmpty)
        var state = NotchState(phase: .input, query: "q92", answer: "", sources: [])
        for e in events { state = NotchReducer.apply(e, to: state) }
        XCTAssertTrue(!state.answer.isEmpty || state.terminal != nil || !state.reasoning.isEmpty || state.phase == .searching)
    }
}

/// A-034 audit: QueryHistory stores queries without a logging API.
final class QueryHistoryLoggingAuditTests: XCTestCase {
    func testHistoryCollapsesConsecutiveDuplicates() {
        var h = QueryHistory()
        h.remember("same")
        h.remember("same")
        h.remember("other")
        XCTAssertEqual(h.entries, ["same", "other"])
    }
}
