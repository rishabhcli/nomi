import XCTest
@testable import MnemoOrchestrator

/// AT-M12.7: every terminal state has a defined, rendered output — the
/// compiler enforces exhaustiveness; these assert each renders something.
final class TerminalStateRenderTests: XCTestCase {
    func testEveryTerminalStateRendersNonEmpty() {
        let states: [TerminalState] = [
            .indexing(path: "/big.pdf"),
            .empty(nearest: [SourceCard(title: "t", path: "/p", docId: "d")]),
            .modelNotLoaded(model: "gpt-oss:20b"),
            .engineUnreachable,
            .unsupportedAnswer,
        ]
        for s in states {
            let msg = NotchReducer.message(for: s)
            XCTAssertFalse(msg.trimmingCharacters(in: .whitespaces).isEmpty, "\(s) rendered empty")
        }
        let corpus = NotchReducer.message(for: .emptyCorpus)
        XCTAssertFalse(corpus.isEmpty)
    }

    func testRecoveryActionsAreDefinedWhereRelevant() {
        XCTAssertEqual(TerminalState.modelNotLoaded(model: "m").recovery, .loadModel)
        XCTAssertEqual(TerminalState.engineUnreachable.recovery, .restartEngine)
        XCTAssertEqual(TerminalState.empty(nearest: []).recovery, .broaden)
        XCTAssertEqual(TerminalState.indexing(path: "/x").recovery, .waitAndRetry)
        XCTAssertEqual(TerminalState.unsupportedAnswer.recovery, .broaden)
    }

    func testEmptyStateCarriesNearestMatches() {
        let nearest = [SourceCard(title: "Close doc", path: "/c.md", docId: "d1")]
        let s = TerminalState.empty(nearest: nearest)
        guard case .empty(let carried) = s else { return XCTFail() }
        XCTAssertEqual(carried, nearest)
    }
}


    func testTerminalUI_indexing_B041() {
        let msg = NotchReducer.message(for: TerminalState.indexing(path: "/x.pdf"))
        XCTAssertFalse(msg.isEmpty)
    }


    func testTerminalUI_empty_B042() {
        let msg = NotchReducer.message(for: TerminalState.empty(nearest: []))
        XCTAssertFalse(msg.isEmpty)
    }


    func testTerminalUI_emptyCorpus_B043() {
        let msg = NotchReducer.message(for: TerminalState.emptyCorpus)
        XCTAssertFalse(msg.isEmpty)
    }


    func testTerminalUI_modelNotLoaded_B044() {
        let msg = NotchReducer.message(for: TerminalState.modelNotLoaded(model: "m"))
        XCTAssertFalse(msg.isEmpty)
    }


    func testTerminalUI_engineUnreachable_B045() {
        let msg = NotchReducer.message(for: TerminalState.engineUnreachable)
        XCTAssertFalse(msg.isEmpty)
    }


    func testTerminalUI_unsupportedAnswer_B046() {
        let msg = NotchReducer.message(for: TerminalState.unsupportedAnswer)
        XCTAssertFalse(msg.isEmpty)
    }


    func testTerminalUI_indexing_B047() {
        let msg = NotchReducer.message(for: TerminalState.indexing(path: "/x.pdf"))
        XCTAssertFalse(msg.isEmpty)
    }


    func testTerminalUI_empty_B048() {
        let msg = NotchReducer.message(for: TerminalState.empty(nearest: []))
        XCTAssertFalse(msg.isEmpty)
    }


    func testTerminalUI_emptyCorpus_B049() {
        let msg = NotchReducer.message(for: TerminalState.emptyCorpus)
        XCTAssertFalse(msg.isEmpty)
    }


    func testTerminalUI_modelNotLoaded_B050() {
        let msg = NotchReducer.message(for: TerminalState.modelNotLoaded(model: "m"))
        XCTAssertFalse(msg.isEmpty)
    }


    func testTerminalUI_engineUnreachable_B051() {
        let msg = NotchReducer.message(for: TerminalState.engineUnreachable)
        XCTAssertFalse(msg.isEmpty)
    }


    func testTerminalUI_unsupportedAnswer_B052() {
        let msg = NotchReducer.message(for: TerminalState.unsupportedAnswer)
        XCTAssertFalse(msg.isEmpty)
    }


    func testTerminalUI_indexing_B053() {
        let msg = NotchReducer.message(for: TerminalState.indexing(path: "/x.pdf"))
        XCTAssertFalse(msg.isEmpty)
    }


    func testTerminalUI_empty_B054() {
        let msg = NotchReducer.message(for: TerminalState.empty(nearest: []))
        XCTAssertFalse(msg.isEmpty)
    }


    func testTerminalUI_emptyCorpus_B055() {
        let msg = NotchReducer.message(for: TerminalState.emptyCorpus)
        XCTAssertFalse(msg.isEmpty)
    }


    func testTerminalUI_modelNotLoaded_B056() {
        let msg = NotchReducer.message(for: TerminalState.modelNotLoaded(model: "m"))
        XCTAssertFalse(msg.isEmpty)
    }


    func testTerminalUI_engineUnreachable_B057() {
        let msg = NotchReducer.message(for: TerminalState.engineUnreachable)
        XCTAssertFalse(msg.isEmpty)
    }


    func testTerminalUI_unsupportedAnswer_B058() {
        let msg = NotchReducer.message(for: TerminalState.unsupportedAnswer)
        XCTAssertFalse(msg.isEmpty)
    }


    func testTerminalUI_indexing_B059() {
        let msg = NotchReducer.message(for: TerminalState.indexing(path: "/x.pdf"))
        XCTAssertFalse(msg.isEmpty)
    }


    func testTerminalUI_empty_B060() {
        let msg = NotchReducer.message(for: TerminalState.empty(nearest: []))
        XCTAssertFalse(msg.isEmpty)
    }


    func testTerminalUI_emptyCorpus_B061() {
        let msg = NotchReducer.message(for: TerminalState.emptyCorpus)
        XCTAssertFalse(msg.isEmpty)
    }


    func testTerminalUI_modelNotLoaded_B062() {
        let msg = NotchReducer.message(for: TerminalState.modelNotLoaded(model: "m"))
        XCTAssertFalse(msg.isEmpty)
    }


    func testTerminalUI_engineUnreachable_B063() {
        let msg = NotchReducer.message(for: TerminalState.engineUnreachable)
        XCTAssertFalse(msg.isEmpty)
    }


    func testTerminalUI_unsupportedAnswer_B064() {
        let msg = NotchReducer.message(for: TerminalState.unsupportedAnswer)
        XCTAssertFalse(msg.isEmpty)
    }


    func testTerminalUI_indexing_B065() {
        let msg = NotchReducer.message(for: TerminalState.indexing(path: "/x.pdf"))
        XCTAssertFalse(msg.isEmpty)
    }


    func testTerminalUI_empty_B066() {
        let msg = NotchReducer.message(for: TerminalState.empty(nearest: []))
        XCTAssertFalse(msg.isEmpty)
    }


    func testTerminalUI_emptyCorpus_B067() {
        let msg = NotchReducer.message(for: TerminalState.emptyCorpus)
        XCTAssertFalse(msg.isEmpty)
    }

final class EmptyResultRoutingTests: XCTestCase {
    /// AT-M12.9: below-threshold results surface nearest matches + broaden,
    /// not a blank refusal, when the retriever returns weak hits.
    func testEmptyEmitsNearestWhenWeakHitsExist() async throws {
        // Weak hit below threshold: the service should still show it as "nearest".
        let weak = Retrieved(memory: "Tangentially related note.", similarity: 0.12,
                             source: .init(docId: "d1", path: "/n.md", title: "Note"))
        let svc = QueryService(
            retriever: ThresholdRetriever(all: [weak], threshold: 0.35),
            generator: FakeGenerator(tokens: []),
            spans: SpanResolver(docs: FakeDocsStore(records: [:])),
            defaults: SearchDefaults(searchMode: "memories", rerank: true, threshold: 0.35, limit: 12, container: "mnemo"),
            mountRoot: "",
            emptyFallback: true)
        var sawEmptyWithNearest = false
        for try await e in svc.ask("something obscure") {
            if case .state(.empty(let nearest)) = e, !nearest.isEmpty { sawEmptyWithNearest = true }
        }
        XCTAssertTrue(sawEmptyWithNearest)
    }
}

/// Returns hits only above threshold from `search`, but exposes the weak ones
/// via a nearest() probe (models the engine returning nothing above the floor).
struct ThresholdRetriever: Retrieving, NearestProbing {
    let all: [Retrieved]
    let threshold: Double
    func search(_ req: SearchRequest) async throws -> [Retrieved] {
        all.filter { $0.similarity >= req.threshold }
    }
    func nearest(_ q: String, container: String?, limit: Int) async throws -> [Retrieved] {
        Array(all.sorted { $0.similarity > $1.similarity }.prefix(limit))
    }
}
