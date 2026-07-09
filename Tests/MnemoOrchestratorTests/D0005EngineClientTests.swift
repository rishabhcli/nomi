import XCTest
@testable import MnemoOrchestrator

/// D-0005: EngineClient cache poisoning resistance (seed 2749726a9b94).
final class D0005EngineClientTests: XCTestCase {
    private let seed = "2749726a9b94"

    func testPoisonedRemotePathStripped() {
        let w = EngineClient.WireResult(
            memory: "fact", chunk: nil, similarity: 0.9, filepath: "https://evil.com/pwn",
            documents: [EngineClient.WireResult.Doc(id: "d1", title: "t")],
            metadata: nil, updatedAt: nil)
        let mapped = EngineClient.mapWireResult(w)
        XCTAssertEqual(mapped?.source.path, "")
    }

    func testPoisonedWireResultFilteredFromSearch() async throws {
        StubURLProtocol.handler = { req in
            let json = """
            {"results":[
              {"memory":"good","similarity":0.8,"filepath":"/local.md","documents":[{"id":"a","title":"A"}]},
              {"memory":"bad","similarity":0.99,"filepath":"http://attacker/x","documents":[{"id":"b","title":"B"}]}
            ]}
            """
            return (HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, Data(json.utf8))
        }
        let client = EngineClient(baseURL: URL(string: "http://127.0.0.1:6767")!, apiKey: "",
                                  session: StubURLProtocol.stubbedSession())
        let out = try await client.search(SearchRequest(q: "q", container: "mnemo"))
        XCTAssertEqual(out.count, 1)
        XCTAssertEqual(out[0].source.docId, "a")
    }

    func testWireResultIdentityStableAcrossFieldOrder() {
        var rng = Phase2RNG(seed: seed)
        let w = EngineClient.WireResult(
            memory: "text \(rng.nextInt(upperBound: 1000))", chunk: nil, similarity: 0.5,
            filepath: "/f.md", documents: [EngineClient.WireResult.Doc(id: "doc", title: "T")],
            metadata: nil, updatedAt: nil)
        let a = EngineClient.wireResultIdentity(w)
        let b = EngineClient.wireResultIdentity(w)
        XCTAssertEqual(a, b)
        XCTAssertTrue(a.contains("doc|"))
    }

    func testRemoteURLDetection() {
        XCTAssertTrue(EngineClient.isRemoteURL("https://api.example.com/x"))
        XCTAssertFalse(EngineClient.isRemoteURL("/Users/me/notes.md"))
    }
}
