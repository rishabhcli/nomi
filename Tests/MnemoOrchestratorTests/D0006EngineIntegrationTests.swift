import XCTest
@testable import MnemoOrchestrator

/// D-0006: EngineIntegration token budget adversarial trim (seed 4f5ad49c2ccf).
final class D0006EngineIntegrationTests: XCTestCase {
    private let seed = "4f5ad49c2ccf"

    private func ev(_ text: String, _ sim: Double) -> Retrieved {
        Retrieved(memory: text, similarity: sim, source: SourceLocator(docId: "d", path: "/f", title: "f"))
    }

    func testAdversarialTrimKeepsHighSimilarity() {
        let pad = String(repeating: "x", count: 600)
        let hits = [ev(pad, 0.1), ev("HIGH VALUE", 0.95)]
        let trimmed = ContainerCatalog.trimEvidenceAdversarial(hits, tokenBudget: 20)
        XCTAssertEqual(trimmed.count, 1)
        XCTAssertTrue(trimmed[0].memory.contains("HIGH VALUE"))
    }

    func testAdversarialTrimCapsChunkSize() {
        let huge = ev(String(repeating: "word ", count: 200), 0.9)
        let trimmed = ContainerCatalog.trimEvidenceAdversarial([huge], tokenBudget: 10_000)
        XCTAssertLessThanOrEqual(trimmed[0].memory.count, 501)
    }

    func testSearchDocumentsPicksHighestScoringChunk() async throws {
        StubURLProtocol.handler = { req in
            let json = """
            {"results":[{"documentId":"d1","title":"N","score":0.5,
              "chunks":[
                {"content":"low","isRelevant":true,"score":0.2},
                {"content":"best chunk","isRelevant":false,"score":0.95}
              ]}]}
            """
            return (HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, Data(json.utf8))
        }
        let client = EngineClient(baseURL: URL(string: "http://127.0.0.1:6767")!, apiKey: "",
                                  session: StubURLProtocol.stubbedSession())
        let hits = try await client.searchDocuments("q", container: nil, limit: 3)
        XCTAssertEqual(hits.first?.memory, "best chunk")
    }

    func testProperty_trimNeverExceedsBudget() {
        var rng = Phase2RNG(seed: seed)
        for _ in 0..<10 {
            let budget = 20 + rng.nextInt(upperBound: 80)
            let hits = (0..<5).map { ev(String(repeating: "w", count: 50 + rng.nextInt(upperBound: 200)),
                                        Double(rng.nextInt(upperBound: 100)) / 100.0) }
            let trimmed = ContainerCatalog.trimEvidenceAdversarial(hits, tokenBudget: budget)
            let used = trimmed.reduce(0) { $0 + TokenEstimate.of($1.memory) }
            XCTAssertLessThanOrEqual(used, budget)
        }
    }
}
