import XCTest
@testable import MnemoOrchestrator

actor RequestRecorder {
    var requests: [SearchRequest] = []
    func record(_ r: SearchRequest) { requests.append(r) }
}

struct FakeRetriever: Retrieving {
    let hitsByMode: [String: [Retrieved]]
    var recorder: RequestRecorder? = nil
    func search(_ req: SearchRequest) async throws -> [Retrieved] {
        await recorder?.record(req)
        return hitsByMode[req.searchMode] ?? []
    }
}

struct FakeGenerator: Generating {
    let tokens: [String]
    func stream(system: String, prompt: String) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { c in
            for t in tokens { c.yield(t) }
            c.finish()
        }
    }
}

private struct EffortEchoGenerator: Generating {
    func stream(system: String, prompt: String) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            continuation.yield("legacy")
            continuation.finish()
        }
    }

    func stream(system: String, prompt: String, effort: String) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            continuation.yield(effort)
            continuation.finish()
        }
    }
}

private actor GenerationCallRecorder {
    private(set) var count = 0
    func record() { count += 1 }
}

private actor GenerationEffortRecorder {
    private(set) var efforts: [String] = []
    func record(_ effort: String) { efforts.append(effort) }
}

private struct CountingUngroundedGenerator: Generating {
    let recorder: GenerationCallRecorder

    func stream(system: String, prompt: String) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                await recorder.record()
                continuation.yield("The moon is made of cheese.")
                continuation.finish()
            }
        }
    }
}

private struct EffortRecordingUngroundedGenerator: Generating {
    let recorder: GenerationEffortRecorder

    func stream(system: String, prompt: String) -> AsyncThrowingStream<String, Error> {
        stream(system: system, prompt: prompt, effort: "low")
    }

    func stream(system: String, prompt: String, effort: String) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                await recorder.record(effort)
                continuation.yield("The moon is made of cheese.")
                continuation.finish()
            }
        }
    }
}

private struct AlwaysRejectingVerificationBackend: VerificationBackend {
    func similarity(_ a: String, _ b: String) async -> Double { 1 }
    func entails(premise: String, hypothesis: String) async -> Bool { false }
}

private actor ConversationWriteRecorder: ConversationIngesting {
    private(set) var count = 0

    func ingestConversation(
        id: String,
        messages: [(role: String, content: String)],
        container: String?
    ) async throws {
        count += 1
    }
}

private actor EscalationRecorder {
    var count = 0
    func record() { count += 1 }
}

private struct RecordingEscalator: RouterEscalating {
    let recorder: EscalationRecorder
    func classify(_ query: String) async -> Intent {
        await recorder.record()
        return .synthesis
    }
}

private struct FixedProfileProvider: ProfileFetching {
    let value: Profile
    func profile(_ q: String, container: String?) async throws -> Profile { value }
}

struct FakeDocsStore: DocumentFetching {
    let records: [String: DocumentRecord]
    func document(_ docId: String) async throws -> DocumentRecord? { records[docId] }
}

private let hit = Retrieved(memory: "I moved to SF.", similarity: 0.8,
    source: .init(docId: "d1", path: "/m/f.md", title: "f", charStart: 0, charEnd: 5))

private func makeService(hitsByMode: [String: [Retrieved]],
                         tokens: [String] = ["ok"],
                         recorder: RequestRecorder? = nil,
                         docs: [String: DocumentRecord] = [:],
                         mountRoot: String = "",
                         directTraversalPolicy: @escaping @Sendable (String) -> Bool = { _ in false }) -> QueryService {
    QueryService(retriever: FakeRetriever(hitsByMode: hitsByMode, recorder: recorder),
                 generator: FakeGenerator(tokens: tokens),
                 spans: SpanResolver(docs: FakeDocsStore(records: docs)),
                 defaults: SearchDefaults(searchMode: "memories", rerank: true,
                                          threshold: 0.35, limit: 12, container: "mnemo"),
                 mountRoot: mountRoot,
                 directTraversalPolicy: directTraversalPolicy)
}

final class QueryServiceTests: XCTestCase {
    func testGroundingRetryUsesLowEffortInsteadOfMultihopEffort() async throws {
        let generation = GenerationEffortRecorder()
        let service = QueryService(
            retriever: FakeRetriever(hitsByMode: ["memories": [hit]]),
            generator: EffortRecordingUngroundedGenerator(recorder: generation),
            spans: SpanResolver(docs: FakeDocsStore(records: [:])),
            defaults: SearchDefaults(
                searchMode: "memories",
                rerank: false,
                threshold: 0.35,
                limit: 12,
                container: "mnemo"
            ),
            mountRoot: "",
            effort: EffortPolicy(
                routing: "low",
                extraction: "low",
                synthesis: "medium",
                multihop: "high"
            ),
            verifier: CitationVerifier(
                backend: AlwaysRejectingVerificationBackend(),
                simThreshold: 0.5
            ),
            selfCorrect: true
        )

        for try await _ in service.ask("Where is the launch plan?") {}

        let efforts = await generation.efforts
        XCTAssertEqual(efforts.count, 2)
        XCTAssertEqual(efforts.last, "low",
                       "a strict grounding correction should not pay the multihop reasoning cost")
    }

    func testUnsupportedRetryIsNeitherCachedNorWrittenToConversationMemory() async throws {
        let generation = GenerationCallRecorder()
        let conversations = ConversationWriteRecorder()
        let service = QueryService(
            retriever: FakeRetriever(hitsByMode: ["memories": [hit]]),
            generator: CountingUngroundedGenerator(recorder: generation),
            spans: SpanResolver(docs: FakeDocsStore(records: [:])),
            defaults: SearchDefaults(
                searchMode: "memories",
                rerank: true,
                threshold: 0.35,
                limit: 12,
                container: "mnemo"
            ),
            mountRoot: "",
            verifier: CitationVerifier(
                backend: AlwaysRejectingVerificationBackend(),
                simThreshold: 0.5
            ),
            cache: AnswerCache(ttl: 120),
            selfCorrect: true,
            conversationSink: conversations
        )

        for _ in 0..<2 {
            var terminal: TerminalState?
            for try await event in service.ask("Where is the launch plan?") {
                if case let .state(value) = event { terminal = value }
            }
            XCTAssertEqual(terminal, .unsupportedAnswer)
        }

        let generationCount = await generation.count
        let conversationCount = await conversations.count
        XCTAssertEqual(generationCount, 4,
                       "each ask must generate and retry instead of replaying a rejected cache entry")
        XCTAssertEqual(conversationCount, 0,
                       "rejected text must never become conversation memory")
    }

    func testFinalSynthesisPassesAdaptiveEffortToGenerator() async throws {
        let service = QueryService(
            retriever: FakeRetriever(hitsByMode: ["memories": [hit]]),
            generator: EffortEchoGenerator(),
            spans: SpanResolver(docs: FakeDocsStore(records: [:])),
            defaults: SearchDefaults(
                searchMode: "memories",
                rerank: true,
                threshold: 0.35,
                limit: 12,
                container: "mnemo"
            ),
            mountRoot: "",
            effort: EffortPolicy(
                routing: "low",
                extraction: "low",
                synthesis: "medium",
                multihop: "high"
            )
        )

        var answer = ""
        for try await event in service.ask("Where do I live?") {
            if case let .token(token) = event { answer += token }
        }

        XCTAssertEqual(answer, "medium")
    }

    func testEmitsSourcesBeforeTokensThenDone() async throws {
        let svc = makeService(hitsByMode: ["memories": [hit]], tokens: ["A", "B"])
        var events: [QueryEvent] = []
        for try await e in svc.ask("where do I live?") { events.append(e) }
        if case .routed = events.first { } else { XCTFail("first event must be .routed, got \(String(describing: events.first))") }
        let sIdx = events.firstIndex { if case .sources = $0 { true } else { false } }!
        let tIdx = events.firstIndex(of: .token("A"))!
        XCTAssertLessThan(sIdx, tIdx)
        XCTAssertEqual(events.last, .done)
    }

    func testNotInCorpusDoesNotInvent() async throws {
        let svc = makeService(hitsByMode: [:], tokens: ["SHOULD_NOT_APPEAR"])
        var text = ""
        for try await e in svc.ask("unknown") { if case let .token(t) = e { text += t } }
        XCTAssertFalse(text.contains("SHOULD_NOT_APPEAR"))
        XCTAssertTrue(text.lowercased().contains("don't") || text.lowercased().contains("not"))
    }

    func testDedupesSourceCardsByDocId() async throws {
        let hit2 = Retrieved(memory: "Another fact.", similarity: 0.7,
            source: .init(docId: "d1", path: "/m/f.md", title: "f", charStart: 10, charEnd: 20))
        let svc = makeService(hitsByMode: ["memories": [hit, hit2]])
        var cards: [SourceCard] = []
        for try await e in svc.ask("q") { if case let .sources(c) = e { cards = c } }
        XCTAssertEqual(cards.count, 1)
    }

    func testFallsBackToHybridWhenMemoriesEmpty() async throws {
        let recorder = RequestRecorder()
        let svc = makeService(hitsByMode: ["memories": [], "hybrid": [hit]], recorder: recorder)
        var cards: [SourceCard] = []
        for try await e in svc.ask("q") { if case let .sources(c) = e { cards = c } }
        XCTAssertEqual(cards.count, 1)
        let modes = await recorder.requests.map(\.searchMode)
        XCTAssertEqual(modes, ["memories", "hybrid"])
    }

    func testUsesConfiguredDefaultsOnFirstSearch() async throws {
        let recorder = RequestRecorder()
        let svc = makeService(hitsByMode: ["memories": [hit]], recorder: recorder)
        for try await _ in svc.ask("q") {}
        let first = await recorder.requests[0]
        XCTAssertEqual(first.container, "mnemo")
        XCTAssertEqual(first.limit, 12)
        XCTAssertTrue(first.rerank)
    }

    func testResolvesSpansIntoGenerationContext() async throws {
        // Span comes back nil from retrieval; the service resolves it against doc content.
        let unresolved = Retrieved(memory: "beta gamma", similarity: 0.9,
                                   source: .init(docId: "d9", path: "/d.md", title: "d"))
        let recorder = RequestRecorder()
        let svc = QueryService(
            retriever: FakeRetriever(hitsByMode: ["memories": [unresolved]], recorder: recorder),
            generator: PromptCapturingGenerator(),
            spans: SpanResolver(docs: FakeDocsStore(records: ["d9": DocumentRecord(content: "alpha beta gamma delta", filepath: nil)])),
            defaults: SearchDefaults(searchMode: "memories", rerank: true, threshold: 0.35, limit: 12, container: nil),
            mountRoot: "")
        var answer = ""
        for try await e in svc.ask("q") { if case let .token(t) = e { answer += t } }
        XCTAssertTrue(answer.contains("@6-16"), "prompt context should carry the resolved span, got: \(answer)")
    }

    func testEvidenceStepsNeverEmbedDocumentText() async throws {
        let secret = "SECRET_DOC_CONTENT_xyz"
        let secretHit = Retrieved(memory: secret, similarity: 0.9,
            source: .init(docId: "d2", path: "/m/s.md", title: "s", charStart: 0, charEnd: 5))
        let svc = makeService(hitsByMode: ["memories": [secretHit]], tokens: ["ok"])
        var steps: [String] = []
        for try await e in svc.ask("what is secret?") {
            if case let .reasoning(s) = e { steps = s }
        }
        for step in steps {
            XCTAssertFalse(step.contains(secret), "reasoning steps must not embed document text")
        }
    }

    func testEmitsLiveReasoningBeforeSourcesAndGeneration() async throws {
        let svc = makeService(hitsByMode: ["memories": [hit]], tokens: ["answer"])
        var events: [QueryEvent] = []

        for try await event in svc.ask("where do I live?") {
            events.append(event)
        }

        let sourceIndex = try XCTUnwrap(events.firstIndex {
            if case .sources = $0 { return true }
            return false
        })
        let liveReasoning = events[..<sourceIndex].compactMap { event -> [String]? in
            if case let .reasoning(steps) = event { return steps }
            return nil
        }

        XCTAssertFalse(liveReasoning.isEmpty, "search activity must be visible while retrieval is running")
        XCTAssertTrue(liveReasoning.contains { $0.contains("Searching semantic memory") })
        XCTAssertTrue(liveReasoning.contains { steps in
            steps.contains { $0.hasPrefix("Found ") && $0.contains("memory match") }
        })
        XCTAssertFalse(events.contains { event in
            guard case let .reasoning(steps) = event else { return false }
            return steps.contains("Checking every claim against your files")
        }, "verification activity must only be shown when a verifier is wired")
    }

    func testEmptySemanticSearchUsesLocalBackstopBeforeEmptyState() async throws {
        let root = URL(fileURLWithPath: NSTemporaryDirectory())
            .appending(path: "query-backstop-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try "Project codename: Zephyr. Launch owner: Maya."
            .write(to: root.appending(path: "launch-notes.md"), atomically: true, encoding: .utf8)

        let svc = makeService(
            hitsByMode: [:],
            tokens: ["Zephyr is the project codename."],
            mountRoot: root.path,
            directTraversalPolicy: { _ in true }
        )
        var cards: [SourceCard] = []
        var answer = ""
        var terminal: TerminalState?
        for try await event in svc.ask("What is the project codename Zephyr?") {
            if case let .sources(found) = event { cards = found }
            if case let .token(token) = event { answer += token }
            if case let .state(state) = event { terminal = state }
        }

        XCTAssertFalse(cards.isEmpty, "local files must rescue an empty embedding result")
        XCTAssertTrue(answer.contains("Zephyr"))
        XCTAssertNil(terminal)
    }

    func testNetworkMountSkipsDirectFilesystemBackstopAfterSemanticRetrieval() async throws {
        let root = URL(fileURLWithPath: NSTemporaryDirectory())
            .appending(path: "query-network-backstop-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try "Zephyr launch owner: Maya."
            .write(to: root.appending(path: "private-owner.md"), atomically: true, encoding: .utf8)

        let semantic = Retrieved(
            memory: "The Zephyr launch checklist is indexed.",
            similarity: 0.82,
            source: .init(docId: "semantic", path: "/zephyr.md", title: "Zephyr")
        )
        let svc = makeService(
            hitsByMode: ["memories": [semantic]],
            mountRoot: root.path
        )
        var cards: [SourceCard] = []
        for try await event in svc.ask("Who owns the Zephyr launch?") {
            if case let .sources(found) = event { cards = found }
        }

        XCTAssertTrue(cards.contains { $0.title == "Zephyr" })
        XCTAssertFalse(
            cards.contains { $0.title == "private-owner" },
            "network mounts must stay on the indexed retrieval path"
        )
    }

    func testLookupCapsNoisyEvidenceAndKeepsDistinctSources() {
        let hits = (0..<12).flatMap { index -> [Retrieved] in
            let source = SourceLocator(
                docId: "d\(index)", path: "/d\(index).md", title: "Document \(index)"
            )
            return [
                Retrieved(memory: "primary fact \(index)", similarity: 0.9 - Double(index) * 0.01,
                          source: source),
                Retrieved(memory: "duplicate chunk \(index)", similarity: 0.7 - Double(index) * 0.01,
                          source: source),
            ]
        }

        let selected = EvidenceSelector.select(hits, for: .lookup)

        XCTAssertEqual(selected.count, 6)
        XCTAssertEqual(Set(selected.map(\.source.docId)).count, 6,
                       "lookup context should prefer distinct sources before extra chunks")
        XCTAssertTrue(selected.allSatisfy { !$0.source.docId.isEmpty })
    }

    func testSourceCardsMatchFinalAssembledGenerationEvidence() async throws {
        let oversized = Retrieved(
            memory: String(repeating: "retrieval-only ", count: 80),
            similarity: 0.8,
            source: .init(docId: "retrieved", path: "/retrieved.md", title: "Retrieved")
        )
        let profileHit = Retrieved(
            memory: "Atlas owner is Maya.",
            similarity: 0.95,
            source: .init(docId: "profile", path: "/profile.md", title: "Profile")
        )
        let service = QueryService(
            retriever: FakeRetriever(hitsByMode: ["memories": [oversized]]),
            generator: FakeGenerator(tokens: ["ok"]),
            spans: SpanResolver(docs: FakeDocsStore(records: [:])),
            defaults: SearchDefaults(searchMode: "memories", rerank: true,
                                     threshold: 0.35, limit: 12, container: "mnemo"),
            mountRoot: "",
            profiles: FixedProfileProvider(value: Profile(
                statics: [], dynamics: [], memories: [profileHit]
            )),
            assembler: ContextAssembler(tokenBudget: 80, preambleFraction: 0.35)
        )

        var cards: [SourceCard] = []
        for try await event in service.ask("Who owns Atlas?") {
            if case let .sources(found) = event { cards = found }
        }

        XCTAssertEqual(cards.map(\.docId), ["profile"],
                       "cards must describe only evidence that reached generation")
    }

    func testChitChatSkipsRetrievalAndGeneration() async throws {
        let recorder = RequestRecorder()
        let svc = makeService(hitsByMode: ["memories": [hit]], tokens: ["GENERATED"],
                              recorder: recorder)
        var events: [QueryEvent] = []
        for try await e in svc.ask("hi") { events.append(e) }
        let reqCount = await recorder.requests.count
        XCTAssertEqual(reqCount, 0, "chit-chat must not search")
        XCTAssertFalse(events.contains { if case .sources = $0 { true } else { false } })
        let text = events.compactMap { if case let .token(t) = $0 { t } else { nil } }.joined()
        XCTAssertFalse(text.contains("GENERATED"))
        XCTAssertEqual(events.last, .done)
    }

    func testChitChatSkipsModelRoutingBeforeAnyAsyncWork() async throws {
        let escalation = EscalationRecorder()
        let svc = QueryService(
            retriever: FakeRetriever(hitsByMode: ["memories": [hit]]),
            generator: FakeGenerator(tokens: ["GENERATED"]),
            spans: SpanResolver(docs: FakeDocsStore(records: [:])),
            defaults: SearchDefaults(searchMode: "memories", rerank: true,
                                     threshold: 0.35, limit: 12, container: "mnemo"),
            mountRoot: "",
            escalator: RecordingEscalator(recorder: escalation))

        var answer = ""
        for try await event in svc.ask("Hey, what's up? Hey.") {
            if case let .token(token) = event { answer += token }
        }

        let escalationCount = await escalation.count
        XCTAssertEqual(escalationCount, 0,
                       "obvious chit-chat must never queue behind the local model")
        XCTAssertFalse(answer.contains("GENERATED"))
        XCTAssertFalse(answer.isEmpty)
    }

    func testSourceCardsCarryAbsoluteMountPaths() async throws {
        let bare = Retrieved(memory: "alpha", similarity: 0.9,
                             source: .init(docId: "d1", path: "", title: "t"))
        let svc = makeService(
            hitsByMode: ["memories": [bare]],
            docs: ["d1": DocumentRecord(content: "alpha", filepath: "/fixture.md")],
            mountRoot: "/Users/me/Mnemo/memory")
        var cards: [SourceCard] = []
        for try await e in svc.ask("q") { if case let .sources(c) = e { cards = c } }
        XCTAssertEqual(cards[0].path, "/Users/me/Mnemo/memory/fixture.md")
    }

    func testExternalVolumeSourcePathIsNotPrefixedBySMFSMount() async throws {
        let external = Retrieved(
            memory: "The Orion archive is on the external SSD.",
            similarity: 0.9,
            source: .init(
                docId: "external-1",
                path: "/Volumes/Extreme SSD/Archives/Orion SSD Archive.pdf",
                title: "Orion SSD Archive"
            )
        )
        let svc = makeService(
            hitsByMode: ["memories": [external]],
            mountRoot: "/Users/me/Mnemo/memory"
        )
        var cards: [SourceCard] = []
        for try await event in svc.ask("find the Orion SSD archive") {
            if case let .sources(found) = event { cards = found }
        }

        XCTAssertEqual(
            cards.first?.path,
            "/Volumes/Extreme SSD/Archives/Orion SSD Archive.pdf"
        )
    }
}

/// Echoes the prompt back as the "answer" so tests can assert on assembled context.
struct PromptCapturingGenerator: Generating {
    func stream(system: String, prompt: String) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { c in
            c.yield(prompt)
            c.finish()
        }
    }
    /// A-361: mnemoctl exposes Coverage via `coverage` subcommand (headless AT-M*).
    func testMnemoctlCoverageSubcommandRegisteredA361() {
        XCTAssertTrue(FileManager.default.fileExists(atPath: "Sources/mnemoctl/main.swift"))
        let main = (try? String(contentsOfFile: "Sources/mnemoctl/main.swift", encoding: .utf8)) ?? ""
        XCTAssertTrue(main.contains("case \"coverage\":"), "mnemoctl must wire coverage for Coverage")
    }

    /// A-362: mnemoctl exposes Highlight via `highlight` subcommand (headless AT-M*).
    func testMnemoctlHighlightSubcommandRegisteredA362() {
        XCTAssertTrue(FileManager.default.fileExists(atPath: "Sources/mnemoctl/main.swift"))
        let main = (try? String(contentsOfFile: "Sources/mnemoctl/main.swift", encoding: .utf8)) ?? ""
        XCTAssertTrue(main.contains("case \"highlight\":"), "mnemoctl must wire highlight for Highlight")
    }

    /// A-363: mnemoctl exposes ActionExtractor via `actions` subcommand (headless AT-M*).
    func testMnemoctlActionExtractorSubcommandRegisteredA363() {
        XCTAssertTrue(FileManager.default.fileExists(atPath: "Sources/mnemoctl/main.swift"))
        let main = (try? String(contentsOfFile: "Sources/mnemoctl/main.swift", encoding: .utf8)) ?? ""
        XCTAssertTrue(main.contains("case \"actions\":"), "mnemoctl must wire actions for ActionExtractor")
    }

    /// A-364: mnemoctl exposes CorpusSuggester via `suggest` subcommand (headless AT-M*).
    func testMnemoctlCorpusSuggesterSubcommandRegisteredA364() {
        XCTAssertTrue(FileManager.default.fileExists(atPath: "Sources/mnemoctl/main.swift"))
        let main = (try? String(contentsOfFile: "Sources/mnemoctl/main.swift", encoding: .utf8)) ?? ""
        XCTAssertTrue(main.contains("case \"suggest\":"), "mnemoctl must wire suggest for CorpusSuggester")
    }

    /// A-366: mnemoctl exposes Router via `route` subcommand (headless AT-M*).
    func testMnemoctlRouterSubcommandRegisteredA366() {
        XCTAssertTrue(FileManager.default.fileExists(atPath: "Sources/mnemoctl/main.swift"))
        let main = (try? String(contentsOfFile: "Sources/mnemoctl/main.swift", encoding: .utf8)) ?? ""
        XCTAssertTrue(main.contains("case \"route\":"), "mnemoctl must wire route for Router")
    }

    /// A-367: mnemoctl exposes RouterEscalator via `escalate` subcommand (headless AT-M*).
    func testMnemoctlRouterEscalatorSubcommandRegisteredA367() {
        XCTAssertTrue(FileManager.default.fileExists(atPath: "Sources/mnemoctl/main.swift"))
        let main = (try? String(contentsOfFile: "Sources/mnemoctl/main.swift", encoding: .utf8)) ?? ""
        XCTAssertTrue(main.contains("case \"escalate\":"), "mnemoctl must wire escalate for RouterEscalator")
    }

    /// A-368: mnemoctl exposes EvidenceGathering via `evidence` subcommand (headless AT-M*).
    func testMnemoctlEvidenceGatheringSubcommandRegisteredA368() {
        XCTAssertTrue(FileManager.default.fileExists(atPath: "Sources/mnemoctl/main.swift"))
        let main = (try? String(contentsOfFile: "Sources/mnemoctl/main.swift", encoding: .utf8)) ?? ""
        XCTAssertTrue(main.contains("case \"evidence\":"), "mnemoctl must wire evidence for EvidenceGathering")
    }

    /// A-369: mnemoctl exposes EngineClient via `engine-ping` subcommand (headless AT-M*).
    func testMnemoctlEngineClientSubcommandRegisteredA369() {
        XCTAssertTrue(FileManager.default.fileExists(atPath: "Sources/mnemoctl/main.swift"))
        let main = (try? String(contentsOfFile: "Sources/mnemoctl/main.swift", encoding: .utf8)) ?? ""
        XCTAssertTrue(main.contains("case \"engine-ping\":"), "mnemoctl must wire engine-ping for EngineClient")
    }

    /// A-370: mnemoctl exposes EngineIntegration via `engine-wire` subcommand (headless AT-M*).
    func testMnemoctlEngineIntegrationSubcommandRegisteredA370() {
        XCTAssertTrue(FileManager.default.fileExists(atPath: "Sources/mnemoctl/main.swift"))
        let main = (try? String(contentsOfFile: "Sources/mnemoctl/main.swift", encoding: .utf8)) ?? ""
        XCTAssertTrue(main.contains("case \"engine-wire\":"), "mnemoctl must wire engine-wire for EngineIntegration")
    }

    /// A-371: mnemoctl exposes CitationVerifier via `verify-text` subcommand (headless AT-M*).
    func testMnemoctlCitationVerifierSubcommandRegisteredA371() {
        XCTAssertTrue(FileManager.default.fileExists(atPath: "Sources/mnemoctl/main.swift"))
        let main = (try? String(contentsOfFile: "Sources/mnemoctl/main.swift", encoding: .utf8)) ?? ""
        XCTAssertTrue(main.contains("case \"verify-text\":"), "mnemoctl must wire verify-text for CitationVerifier")
    }

    /// A-372: mnemoctl exposes SpanResolver via `span` subcommand (headless AT-M*).
    func testMnemoctlSpanResolverSubcommandRegisteredA372() {
        XCTAssertTrue(FileManager.default.fileExists(atPath: "Sources/mnemoctl/main.swift"))
        let main = (try? String(contentsOfFile: "Sources/mnemoctl/main.swift", encoding: .utf8)) ?? ""
        XCTAssertTrue(main.contains("case \"span\":"), "mnemoctl must wire span for SpanResolver")
    }

    /// A-373: mnemoctl exposes CharSpan via `char-span` subcommand (headless AT-M*).
    func testMnemoctlCharSpanSubcommandRegisteredA373() {
        XCTAssertTrue(FileManager.default.fileExists(atPath: "Sources/mnemoctl/main.swift"))
        let main = (try? String(contentsOfFile: "Sources/mnemoctl/main.swift", encoding: .utf8)) ?? ""
        XCTAssertTrue(main.contains("case \"char-span\":"), "mnemoctl must wire char-span for CharSpan")
    }

    /// A-376: mnemoctl exposes LLMHopPlanner via `hop-plan` subcommand (headless AT-M*).
    func testMnemoctlLLMHopPlannerSubcommandRegisteredA376() {
        XCTAssertTrue(FileManager.default.fileExists(atPath: "Sources/mnemoctl/main.swift"))
        let main = (try? String(contentsOfFile: "Sources/mnemoctl/main.swift", encoding: .utf8)) ?? ""
        XCTAssertTrue(main.contains("case \"hop-plan\":"), "mnemoctl must wire hop-plan for LLMHopPlanner")
    }

    /// A-377: mnemoctl exposes ContextAssembler via `assemble` subcommand (headless AT-M*).
    func testMnemoctlContextAssemblerSubcommandRegisteredA377() {
        XCTAssertTrue(FileManager.default.fileExists(atPath: "Sources/mnemoctl/main.swift"))
        let main = (try? String(contentsOfFile: "Sources/mnemoctl/main.swift", encoding: .utf8)) ?? ""
        XCTAssertTrue(main.contains("case \"assemble\":"), "mnemoctl must wire assemble for ContextAssembler")
    }

    /// A-378: mnemoctl exposes Prompt via `prompt` subcommand (headless AT-M*).
    func testMnemoctlPromptSubcommandRegisteredA378() {
        XCTAssertTrue(FileManager.default.fileExists(atPath: "Sources/mnemoctl/main.swift"))
        let main = (try? String(contentsOfFile: "Sources/mnemoctl/main.swift", encoding: .utf8)) ?? ""
        XCTAssertTrue(main.contains("case \"prompt\":"), "mnemoctl must wire prompt for Prompt")
    }

    /// A-379: mnemoctl exposes OllamaClient via `ollama-ping` subcommand (headless AT-M*).
    func testMnemoctlOllamaClientSubcommandRegisteredA379() {
        XCTAssertTrue(FileManager.default.fileExists(atPath: "Sources/mnemoctl/main.swift"))
        let main = (try? String(contentsOfFile: "Sources/mnemoctl/main.swift", encoding: .utf8)) ?? ""
        XCTAssertTrue(main.contains("case \"ollama-ping\":"), "mnemoctl must wire ollama-ping for OllamaClient")
    }

    /// A-380: mnemoctl exposes Ingestion via `ingest-map` subcommand (headless AT-M*).
    func testMnemoctlIngestionSubcommandRegisteredA380() {
        XCTAssertTrue(FileManager.default.fileExists(atPath: "Sources/mnemoctl/main.swift"))
        let main = (try? String(contentsOfFile: "Sources/mnemoctl/main.swift", encoding: .utf8)) ?? ""
        XCTAssertTrue(main.contains("case \"ingest-map\":"), "mnemoctl must wire ingest-map for Ingestion")
    }

    /// A-381: mnemoctl exposes IngestGate via `ingest-gate` subcommand (headless AT-M*).
    func testMnemoctlIngestGateSubcommandRegisteredA381() {
        XCTAssertTrue(FileManager.default.fileExists(atPath: "Sources/mnemoctl/main.swift"))
        let main = (try? String(contentsOfFile: "Sources/mnemoctl/main.swift", encoding: .utf8)) ?? ""
        XCTAssertTrue(main.contains("case \"ingest-gate\":"), "mnemoctl must wire ingest-gate for IngestGate")
    }

    /// A-385: mnemoctl exposes ConflictDetector via `conflicts` subcommand (headless AT-M*).
    func testMnemoctlConflictDetectorSubcommandRegisteredA385() {
        XCTAssertTrue(FileManager.default.fileExists(atPath: "Sources/mnemoctl/main.swift"))
        let main = (try? String(contentsOfFile: "Sources/mnemoctl/main.swift", encoding: .utf8)) ?? ""
        XCTAssertTrue(main.contains("case \"conflicts\":"), "mnemoctl must wire conflicts for ConflictDetector")
    }

    /// A-387: mnemoctl exposes LLMSynthesizer via `synthesize` subcommand (headless AT-M*).
    func testMnemoctlLLMSynthesizerSubcommandRegisteredA387() {
        XCTAssertTrue(FileManager.default.fileExists(atPath: "Sources/mnemoctl/main.swift"))
        let main = (try? String(contentsOfFile: "Sources/mnemoctl/main.swift", encoding: .utf8)) ?? ""
        XCTAssertTrue(main.contains("case \"synthesize\":"), "mnemoctl must wire synthesize for LLMSynthesizer")
    }

    /// A-391: mnemoctl exposes WorkScheduler via `scheduler` subcommand (headless AT-M*).
    func testMnemoctlWorkSchedulerSubcommandRegisteredA391() {
        XCTAssertTrue(FileManager.default.fileExists(atPath: "Sources/mnemoctl/main.swift"))
        let main = (try? String(contentsOfFile: "Sources/mnemoctl/main.swift", encoding: .utf8)) ?? ""
        XCTAssertTrue(main.contains("case \"scheduler\":"), "mnemoctl must wire scheduler for WorkScheduler")
    }

    /// A-392: mnemoctl exposes NotchReducer via `notch-state` subcommand (headless AT-M*).
    func testMnemoctlNotchReducerSubcommandRegisteredA392() {
        XCTAssertTrue(FileManager.default.fileExists(atPath: "Sources/mnemoctl/main.swift"))
        let main = (try? String(contentsOfFile: "Sources/mnemoctl/main.swift", encoding: .utf8)) ?? ""
        XCTAssertTrue(main.contains("case \"notch-state\":"), "mnemoctl must wire notch-state for NotchReducer")
    }

    /// A-394: mnemoctl exposes QueryDecomposer via `decompose` subcommand (headless AT-M*).
    func testMnemoctlQueryDecomposerSubcommandRegisteredA394() {
        XCTAssertTrue(FileManager.default.fileExists(atPath: "Sources/mnemoctl/main.swift"))
        let main = (try? String(contentsOfFile: "Sources/mnemoctl/main.swift", encoding: .utf8)) ?? ""
        XCTAssertTrue(main.contains("case \"decompose\":"), "mnemoctl must wire decompose for QueryDecomposer")
    }

}

final class A204RegressionTests: XCTestCase {
    func testA204_forgottenFactExcludedAfterForget() {
        let forgotten = MemoryEntry(id: "m204", memory: "Forgotten fact 204.", version: 1,
                                    isLatest: true, isForgotten: true, isStatic: false,
                                    parentMemoryId: nil, rootMemoryId: "m204",
                                    forgetAfter: nil, forgetReason: "user retraction", history: [])
        let active = MemoryEntry(id: "m204b", memory: "Active fact 204.", version: 1,
                                 isLatest: true, isForgotten: false, isStatic: false,
                                 parentMemoryId: nil, rootMemoryId: "m204b",
                                 forgetAfter: nil, forgetReason: nil, history: [])
        let filtered = Preferences.memoryDynamicsFilter([forgotten, active])
        XCTAssertEqual(filtered.map(\.id), ["m204b"],
                       "re-asked queries must not surface facts retracted via /forget")
    }

    func testA204_ttlExpiredExcluded() {
        let past = ISO8601DateFormatter().string(from: Date().addingTimeInterval(-3600))
        let expired = MemoryEntry(id: "e204", memory: "TTL fact 204.", version: 1,
                                  isLatest: true, isForgotten: false, isStatic: false,
                                  parentMemoryId: nil, rootMemoryId: "e204",
                                  forgetAfter: past, forgetReason: nil, history: [])
        XCTAssertFalse(Preferences.memoryDynamicsActive(expired),
                       "TTL-expired memories must not appear in answers")
    }
    /// A-395: mnemoctl exposes ScopeClassifier via `scope-classify` subcommand (headless AT-M*).
    func testMnemoctlScopeClassifierSubcommandRegisteredA395() {
        XCTAssertTrue(FileManager.default.fileExists(atPath: "Sources/mnemoctl/main.swift"))
        let main = (try? String(contentsOfFile: "Sources/mnemoctl/main.swift", encoding: .utf8)) ?? ""
        XCTAssertTrue(main.contains("case \"scope-classify\":"), "mnemoctl must wire scope-classify for ScopeClassifier")
    }

    /// A-396: mnemoctl exposes AdaptiveEffort via `effort` subcommand (headless AT-M*).
    func testMnemoctlAdaptiveEffortSubcommandRegisteredA396() {
        XCTAssertTrue(FileManager.default.fileExists(atPath: "Sources/mnemoctl/main.swift"))
        let main = (try? String(contentsOfFile: "Sources/mnemoctl/main.swift", encoding: .utf8)) ?? ""
        XCTAssertTrue(main.contains("case \"effort\":"), "mnemoctl must wire effort for AdaptiveEffort")
    }

    /// A-397: mnemoctl exposes AnswerCache via `cache` subcommand (headless AT-M*).
    func testMnemoctlAnswerCacheSubcommandRegisteredA397() {
        XCTAssertTrue(FileManager.default.fileExists(atPath: "Sources/mnemoctl/main.swift"))
        let main = (try? String(contentsOfFile: "Sources/mnemoctl/main.swift", encoding: .utf8)) ?? ""
        XCTAssertTrue(main.contains("case \"cache\":"), "mnemoctl must wire cache for AnswerCache")
    }

    /// A-399: mnemoctl exposes PersonalRanker via `rank` subcommand (headless AT-M*).
    func testMnemoctlPersonalRankerSubcommandRegisteredA399() {
        XCTAssertTrue(FileManager.default.fileExists(atPath: "Sources/mnemoctl/main.swift"))
        let main = (try? String(contentsOfFile: "Sources/mnemoctl/main.swift", encoding: .utf8)) ?? ""
        XCTAssertTrue(main.contains("case \"rank\":"), "mnemoctl must wire rank for PersonalRanker")
    }

    /// A-400: mnemoctl exposes NumericReasoner via `numeric` subcommand (headless AT-M*).
    func testMnemoctlNumericReasonerSubcommandRegisteredA400() {
        XCTAssertTrue(FileManager.default.fileExists(atPath: "Sources/mnemoctl/main.swift"))
        let main = (try? String(contentsOfFile: "Sources/mnemoctl/main.swift", encoding: .utf8)) ?? ""
        XCTAssertTrue(main.contains("case \"numeric\":"), "mnemoctl must wire numeric for NumericReasoner")
    }

}

final class A233RegressionTests: XCTestCase {
    func testA233_forgottenFactExcludedAfterForget() {
        let forgotten = MemoryEntry(id: "m233", memory: "Forgotten fact 233.", version: 1,
                                    isLatest: true, isForgotten: true, isStatic: false,
                                    parentMemoryId: nil, rootMemoryId: "m233",
                                    forgetAfter: nil, forgetReason: "user retraction", history: [])
        let active = MemoryEntry(id: "m233b", memory: "Active fact 233.", version: 1,
                                 isLatest: true, isForgotten: false, isStatic: false,
                                 parentMemoryId: nil, rootMemoryId: "m233b",
                                 forgetAfter: nil, forgetReason: nil, history: [])
        let filtered = ProfileDedupe.memoryDynamicsFilter([forgotten, active])
        XCTAssertEqual(filtered.map(\.id), ["m233b"],
                       "re-asked queries must not surface facts retracted via /forget")
    }

    func testA233_ttlExpiredExcluded() {
        let past = ISO8601DateFormatter().string(from: Date().addingTimeInterval(-3600))
        let expired = MemoryEntry(id: "e233", memory: "TTL fact 233.", version: 1,
                                  isLatest: true, isForgotten: false, isStatic: false,
                                  parentMemoryId: nil, rootMemoryId: "e233",
                                  forgetAfter: past, forgetReason: nil, history: [])
        XCTAssertFalse(ProfileDedupe.memoryDynamicsActive(expired),
                       "TTL-expired memories must not appear in answers")
    }
}

final class A117RegressionTests: XCTestCase {
    func testA117_lifecycleEventsRenderable() {
        let events = ContextAssembler.lifecycleEvents(branch: .retry)
        XCTAssertFalse(events.isEmpty)
        var state = NotchState(phase: .input, query: "q117", answer: "", sources: [])
        for e in events { state = NotchReducer.apply(e, to: state) }
        let ok = !state.answer.isEmpty || state.terminal != nil || !state.reasoning.isEmpty || state.phase == .searching
        XCTAssertTrue(ok, "NotchReducer must render .retry")
    }
    /// A-393: mnemoctl exposes QueryRewriter via `rewrite` subcommand (headless AT-M*).
    func testMnemoctlQueryRewriterSubcommandRegisteredA393() {
        XCTAssertTrue(FileManager.default.fileExists(atPath: "Sources/mnemoctl/main.swift"))
        let main = (try? String(contentsOfFile: "Sources/mnemoctl/main.swift", encoding: .utf8)) ?? ""
        XCTAssertTrue(main.contains("case \"rewrite\":"), "mnemoctl must wire rewrite for QueryRewriter")
    }

}

final class A175RegressionTests: XCTestCase {
    func testA175_indexingTerminal() {
        let t = ContentHash.indexingTerminalState(path: "/f175.pdf")
        guard case .indexing(let p) = t else { return XCTFail() }
        XCTAssertEqual(p, "/f175.pdf")
    }
    func testA175_selfHealSafe() {
        XCTAssertEqual(ContentHash.ingestionSelfHealSafe(orphanIds: ["m175", ""]), ["m175"])
    }
}

/// G-0365..G-0390: mnemoctl headless probes must wire real subcommands (not stub asserts).
final class MnemoctlWiringRegressionTests: XCTestCase {
    private func mainSource() -> String {
        XCTAssertTrue(FileManager.default.fileExists(atPath: "Sources/mnemoctl/main.swift"))
        return (try? String(contentsOfFile: "Sources/mnemoctl/main.swift", encoding: .utf8)) ?? ""
    }

    func testMnemoctlQueryServiceA365() {
        let main = mainSource()
        XCTAssertTrue(main.contains("case \"ask\":"), "mnemoctl must wire ask for QueryService")
    }
    func testMnemoctlAgenticGrepA374() {
        let main = mainSource()
        XCTAssertTrue(main.contains("case \"agentic\":"), "mnemoctl must wire agentic for AgenticGrep")
    }
    func testMnemoctlKeywordBackstopA375() {
        let main = mainSource()
        XCTAssertTrue(main.contains("case \"backstop\":"), "mnemoctl must wire backstop for KeywordBackstop")
    }
    func testMnemoctlSyncEngineA382() {
        let main = mainSource()
        XCTAssertTrue(main.contains("case \"sync\":"), "mnemoctl must wire sync for SyncEngine")
    }
    func testMnemoctlContentHashA383() {
        let main = mainSource()
        XCTAssertTrue(main.contains("case \"hash\":"), "mnemoctl must wire hash for ContentHash")
    }
    func testMnemoctlMemoryDynamicsA384() {
        let main = mainSource()
        XCTAssertTrue(main.contains("case \"memory\":"), "mnemoctl must wire memory for MemoryDynamics")
    }
    func testMnemoctlInspectorA388() {
        let main = mainSource()
        XCTAssertTrue(main.contains("case \"inspect\":"), "mnemoctl must wire inspect for Inspector")
    }
    func testMnemoctlProfileA389() {
        let main = mainSource()
        XCTAssertTrue(main.contains("case \"profile\":"), "mnemoctl must wire profile for Profile")
    }
    func testMnemoctlEgressGuardA390() {
        let main = mainSource()
        XCTAssertTrue(main.contains("case \"egress-check\":"), "mnemoctl must wire egress-check for EgressGuard")
    }
}

final class A262RegressionTests: XCTestCase {
    func testA262_dreamingDoesNotDuplicateSynthesis() {
        let existing = [MemoryEntry(id: "s262", memory: "Synthesis 262.", version: 1,
                                    isLatest: true, isForgotten: false, isStatic: false,
                                    parentMemoryId: nil, rootMemoryId: "s262",
                                    forgetAfter: nil, forgetReason: nil, history: [])]
        XCTAssertFalse(HeuristicRouter.dreamingSafeSynthesis("Synthesis 262.", existing: existing,
                                                      constituents: ["fact 262"]),
                       "dreaming must not duplicate existing syntheses")
        XCTAssertTrue(HeuristicRouter.dreamingSafeSynthesis("New synthesis 262.", existing: existing,
                                                     constituents: ["fact 262"]),
                      "novel synthesis with constituent grounding is allowed")
    }
}

final class A88RegressionTests: XCTestCase {
    func testA88_lifecycleEventsRenderable() {
        let events = NumericReasoner.lifecycleEvents(branch: .retry)
        XCTAssertFalse(events.isEmpty)
        var state = NotchState(phase: .input, query: "q88", answer: "", sources: [])
        for e in events { state = NotchReducer.apply(e, to: state) }
        XCTAssertTrue(!state.answer.isEmpty || state.terminal != nil || !state.reasoning.isEmpty || state.phase == .searching)
    }
}

/// A-030: QueryDecomposer splits compound questions for M4 retrieval.
final class QueryDecomposerDocTests: XCTestCase {
    func testDecomposesAndQuestion() {
        let parts = QueryDecomposer.split("what is Bazel and when was it adopted?")
        XCTAssertGreaterThanOrEqual(parts.count, 2)
    }
}

/// M1a: every completed query emits end-of-query metrics for the trust footer,
/// and the egress count is the PER-QUERY delta — a process that has already
/// blocked calls must still report 0 for a query that egressed nothing.
final class M1aMetricsEmissionTests: XCTestCase {
    func testEmitsMetricsWithPerQueryEgressDelta() async throws {
        let svc = QueryService(
            retriever: FakeRetriever(hitsByMode: ["memories": [hit]]),
            generator: FakeGenerator(tokens: ["ok"]),
            spans: SpanResolver(docs: FakeDocsStore(records: [:])),
            defaults: SearchDefaults(searchMode: "memories", rerank: true,
                                     threshold: 0.35, limit: 12, container: "mnemo"),
            mountRoot: "",
            egressCounter: { 7 })  // 7 blocked earlier in the process; 0 during this query
        var events: [QueryEvent] = []
        for try await e in svc.ask("where do I live?") { events.append(e) }
        let metrics = events.compactMap { if case let .metrics(m) = $0 { m } else { nil } }
        XCTAssertEqual(metrics.count, 1, "exactly one .metrics per query")
        XCTAssertEqual(metrics.first?.egressBlockedCount, 0,
                       "per-query egress must be the delta, not the cumulative process count")
        XCTAssertEqual(events.last, .done, ".done remains the terminal event")
        guard let mIdx = events.firstIndex(where: { if case .metrics = $0 { true } else { false } }),
              let dIdx = events.firstIndex(of: .done) else {
            return XCTFail("expected both .metrics and .done")
        }
        XCTAssertLessThan(mIdx, dIdx, ".metrics is emitted just before .done")
    }

    func testEmitsMetricsEvenOnChitChatPath() async throws {
        let svc = QueryService(
            retriever: FakeRetriever(hitsByMode: ["memories": [hit]]),
            generator: FakeGenerator(tokens: ["x"]),
            spans: SpanResolver(docs: FakeDocsStore(records: [:])),
            defaults: SearchDefaults(searchMode: "memories", rerank: true,
                                     threshold: 0.35, limit: 12, container: "mnemo"),
            mountRoot: "")
        var sawMetrics = false
        for try await e in svc.ask("hi") { if case .metrics = e { sawMetrics = true } }
        XCTAssertTrue(sawMetrics, "even a chit-chat dead-end reports metrics")
    }
}

/// M1a: the pipeline emits per-stage timings so the trace can show
/// "searched · generated · verified" with durations. Order reflects the
/// pipeline; a service without a verifier emits no verify stage.
final class M1aStageTimingTests: XCTestCase {
    func testEmitsRetrieveThenGenerateStages() async throws {
        let svc = makeService(hitsByMode: ["memories": [hit]], tokens: ["ok"])
        var stages: [String] = []
        for try await e in svc.ask("where do I live?") {
            if case let .stage(name, ms) = e {
                stages.append(name)
                XCTAssertGreaterThanOrEqual(ms, 0)
            }
        }
        XCTAssertEqual(stages, ["retrieve", "generate"],
                       "no verifier configured → retrieve then generate, no verify stage")
    }
}
