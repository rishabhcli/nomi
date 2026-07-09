import XCTest
@testable import MnemoOrchestrator

/// D-0004: EvidenceGathering offline refusal paths (seed 559d84de90de).
final class D0004EvidenceGatheringTests: XCTestCase {
    private let seed = "559d84de90de"

    private func hit(_ mem: String, title: String = "doc") -> Retrieved {
        Retrieved(memory: mem, similarity: 0.8,
                  source: SourceLocator(docId: "d1", path: "/a.md", title: title))
    }

    func testOfflineRefusalEventsRenderable() {
        var state = NotchState(phase: .input, query: "q", answer: "", sources: [])
        for e in QueryService.offlineRefusalEvents() where e != .done {
            state = NotchReducer.apply(e, to: state)
        }
        XCTAssertNotNil(state.terminal)
        XCTAssertFalse(NotchReducer.message(for: state.terminal!).isEmpty)
    }

    func testChatRecallAloneIsNotPrimaryEvidence() {
        let recall = hit("some fact", title: QueryService.chatRecallTitle)
        XCTAssertFalse(QueryService.hasPrimaryEvidence([recall]))
    }

    func testQueryEchoDetectedDeterministically() {
        var rng = Phase2RNG(seed: seed)
        let q = rng.randomQuery(length: 3)
        let echo = hit(q)
        let fact = hit("unrelated document content about bazel builds")
        XCTAssertTrue(QueryService.isQueryEcho(echo, query: q))
        XCTAssertFalse(QueryService.isQueryEcho(fact, query: q))
    }

    func testGatherEvidenceStripsChatOnlyHits() async throws {
        struct ChatOnlyRetriever: Retrieving, DocumentSearching {
            func search(_ req: SearchRequest) async throws -> [Retrieved] {
                if req.container == "mnemo-chat" {
                    return [Retrieved(memory: "prior chat fact", similarity: 0.7,
                                      source: SourceLocator(docId: "c1", path: "", title: QueryService.chatRecallTitle))]
                }
                return []
            }
            func searchDocuments(_ q: String, container: String?, limit: Int) async throws -> [Retrieved] { [] }
        }
        let svc = QueryService(
            retriever: ChatOnlyRetriever(),
            generator: FakeGenerator(tokens: ["x"]),
            spans: SpanResolver(docs: FakeDocsStore(records: [:])),
            defaults: SearchDefaults(searchMode: "memories", rerank: true, threshold: 0.35, limit: 12, container: "mnemo"),
            mountRoot: "",
            chatRecallEnabled: true,
            documentSearchEnabled: true)
        let gathered = try await svc.gatherEvidence("what is alpha?", intent: .lookup)
        XCTAssertTrue(gathered.hits.isEmpty)
        XCTAssertTrue(gathered.steps.contains { $0.contains("not grounded in documents") })
    }

    func testProperty_offlineRefusalStepsNeverEmpty() async throws {
        var rng = Phase2RNG(seed: seed)
        for _ in 0..<8 {
            let q = rng.randomQuery(length: 2 + rng.nextInt(upperBound: 4))
            let svc = QueryService(
                retriever: FakeRetriever(hitsByMode: [:]),
                generator: FakeGenerator(tokens: ["ok"]),
                spans: SpanResolver(docs: FakeDocsStore(records: [:])),
                defaults: SearchDefaults(searchMode: "memories", rerank: true, threshold: 0.35, limit: 12, container: "mnemo"),
                mountRoot: "")
            let gathered = try await svc.gatherEvidence(q, intent: .lookup)
            XCTAssertTrue(gathered.steps.contains { $0.contains("Searched memory") })
        }
    }
}
