import XCTest
@testable import MnemoOrchestrator

private struct StubContainerRetriever: Retrieving {
    let byContainer: [String: [Retrieved]]
    func search(_ req: SearchRequest) async throws -> [Retrieved] {
        byContainer[req.container ?? ""] ?? []
    }
}

private func hit(_ docId: String, _ similarity: Double) -> Retrieved {
    Retrieved(memory: "m-\(docId)", similarity: similarity,
              source: SourceLocator(docId: docId, path: "", title: docId))
}

/// M13: one query fans out across every enabled source container and merges.
final class MultiContainerRetrieverTests: XCTestCase {
    private let sample: [String: [Retrieved]] = [
        "files": [hit("f1", 0.4), hit("f2", 0.9)],
        "messages": [hit("m1", 0.7)],
    ]

    func testFansOutAndMergesSortedBySimilarity() async throws {
        let r = MultiContainerRetriever(base: StubContainerRetriever(byContainer: sample),
                                        containers: ["files", "messages"])
        let out = try await r.search(SearchRequest(q: "x", limit: 10))
        XCTAssertEqual(out.map(\.source.docId), ["f2", "m1", "f1"])
    }

    func testDedupsSameDocKeepingHighestSimilarity() async throws {
        let fake = StubContainerRetriever(byContainer: [
            "files": [hit("dup", 0.3)],
            "messages": [hit("dup", 0.8)],
        ])
        let r = MultiContainerRetriever(base: fake, containers: ["files", "messages"])
        let out = try await r.search(SearchRequest(q: "x", limit: 10))
        XCTAssertEqual(out.count, 1)
        XCTAssertEqual(out.first?.similarity, 0.8)
    }

    func testAppliesLimitAcrossContainers() async throws {
        let r = MultiContainerRetriever(base: StubContainerRetriever(byContainer: sample),
                                        containers: ["files", "messages"])
        let out = try await r.search(SearchRequest(q: "x", limit: 2))
        XCTAssertEqual(out.map(\.source.docId), ["f2", "m1"])
    }

    func testEmptyContainersPassesThroughToBase() async throws {
        let fake = StubContainerRetriever(byContainer: ["": [hit("base", 0.5)]])
        let r = MultiContainerRetriever(base: fake, containers: [])
        let out = try await r.search(SearchRequest(q: "x"))
        XCTAssertEqual(out.map(\.source.docId), ["base"])
    }
}
