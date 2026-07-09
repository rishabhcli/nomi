import XCTest
@testable import MnemoOrchestrator

// MARK: - #2 Status labels

final class StatusLabelTests: XCTestCase {
    func testStatusProgressesThroughLifecycle() {
        var s = NotchState(phase: .input, query: "q", answer: "", sources: [])
        s = NotchReducer.apply(.routed(intent: "synthesis", effort: "medium"), to: s)
        XCTAssertEqual(s.status, "Searching your memory…")
        s = NotchReducer.apply(.sources([SourceCard(title: "t", path: "/p", docId: "d")]), to: s)
        XCTAssertEqual(s.status, "Reading your files…")
        s = NotchReducer.apply(.token("A"), to: s)
        XCTAssertEqual(s.status, "", "no status label once the answer is streaming")
    }

    func testTerminalClearsStatus() {
        var s = NotchState(phase: .searching, query: "q", answer: "", sources: [])
        s.status = "Searching your memory…"
        s = NotchReducer.apply(.state(.engineUnreachable), to: s)
        XCTAssertEqual(s.status, "")
    }
}

// MARK: - #3 Conversation turns

final class ConversationTurnTests: XCTestCase {
    func testCompletedTurnIsRecordedOnDone() {
        var s = NotchState(phase: .input, query: "what is my build tool?", answer: "", sources: [])
        s = NotchReducer.apply(.routed(intent: "lookup", effort: "medium"), to: s)
        s = NotchReducer.apply(.token("Bazel."), to: s)
        s = NotchReducer.apply(.done, to: s)
        XCTAssertEqual(s.transcript.count, 1)
        XCTAssertEqual(s.transcript[0].question, "what is my build tool?")
        XCTAssertEqual(s.transcript[0].answer, "Bazel.")
    }

    func testFollowUpKeepsPriorTurns() {
        var s = NotchState(phase: .input, query: "q1", answer: "", sources: [])
        s = NotchReducer.apply(.routed(intent: "lookup", effort: "medium"), to: s)
        s = NotchReducer.apply(.token("A1"), to: s)
        s = NotchReducer.apply(.done, to: s)
        // Follow-up: new query, prior turn preserved.
        s.query = "q2"
        s = NotchReducer.apply(.routed(intent: "lookup", effort: "medium"), to: s)
        s = NotchReducer.apply(.token("A2"), to: s)
        s = NotchReducer.apply(.done, to: s)
        XCTAssertEqual(s.transcript.map(\.question), ["q1", "q2"])
        XCTAssertEqual(s.transcript.map(\.answer), ["A1", "A2"])
    }

    func testDoneWithoutAnswerRecordsNoTurn() {
        var s = NotchState(phase: .input, query: "q", answer: "", sources: [])
        s = NotchReducer.apply(.routed(intent: "lookup", effort: "medium"), to: s)
        s = NotchReducer.apply(.state(.empty(nearest: [])), to: s)
        s = NotchReducer.apply(.done, to: s)
        XCTAssertTrue(s.transcript.isEmpty, "a non-answer outcome is not a conversation turn")
    }
}

// MARK: - #9 Source snippets

final class SourceSnippetTests: XCTestCase {
    func testSourceCardCarriesQuotedSnippet() async throws {
        let hit = Retrieved(memory: "The Orion kickoff moved to September 14.", similarity: 0.9,
                            source: .init(docId: "d1", path: "/notes.md", title: "Notes"))
        let svc = QueryService(
            retriever: FakeRetriever(hitsByMode: ["memories": [hit]]),
            generator: FakeGenerator(tokens: ["ok"]),
            spans: SpanResolver(docs: FakeDocsStore(records: [:])),
            defaults: SearchDefaults(searchMode: "memories", rerank: true, threshold: 0.35, limit: 12, container: "mnemo"),
            mountRoot: "")
        var cards: [SourceCard] = []
        for try await e in svc.ask("when is kickoff?") { if case let .sources(c) = e { cards = c } }
        XCTAssertEqual(cards.count, 1)
        XCTAssertEqual(cards[0].snippet, "The Orion kickoff moved to September 14.")
    }
}

// MARK: - #7 Empty-corpus onboarding

final class OnboardingStateTests: XCTestCase {
    func testEmptyCorpusEmitsOnboardingNotRefusal() async throws {
        // No docs at all + no hits → onboarding, not "I don't have anything".
        let source = FakeDocumentSource([])
        let index = IngestIndex(docs: source, container: "mnemo")
        await index.refresh()
        let svc = QueryService(
            retriever: FakeRetriever(hitsByMode: [:]),
            generator: FakeGenerator(tokens: ["nope"]),
            spans: SpanResolver(docs: FakeDocsStore(records: [:])),
            defaults: SearchDefaults(searchMode: "memories", rerank: true, threshold: 0.35, limit: 12, container: "mnemo"),
            mountRoot: "",
            ingestIndex: index)
        var sawOnboarding = false
        for try await e in svc.ask("anything") {
            if case .state(.emptyCorpus) = e { sawOnboarding = true }
        }
        XCTAssertTrue(sawOnboarding)
    }

    func testOnboardingMessageAndRecovery() {
        XCTAssertEqual(TerminalState.emptyCorpus.recovery, .addFiles)
        XCTAssertTrue(NotchReducer.message(for: .emptyCorpus).lowercased().contains("mnemo/memory"))
    }
}
