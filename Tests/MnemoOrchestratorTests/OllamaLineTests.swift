import XCTest
@testable import MnemoOrchestrator

final class OllamaLineTests: XCTestCase {
    func testParsesResponseToken() {
        XCTAssertEqual(OllamaLine.parse(#"{"response":"Hello","done":false}"#), "Hello")
    }
    func testDoneLineYieldsNil() {
        XCTAssertNil(OllamaLine.parse(#"{"response":"","done":true}"#))
        XCTAssertNil(OllamaLine.parse(""))
    }
    func testGarbageYieldsNil() {
        XCTAssertNil(OllamaLine.parse("not json"))
    }
    func testErrorLineDetected() {
        XCTAssertEqual(OllamaLine.error(#"{"error":"runner crashed"}"#), "runner crashed")
        XCTAssertNil(OllamaLine.error(#"{"response":"Hello","done":false}"#))
        XCTAssertNil(OllamaLine.error("not json"))
    }
}

/// A failed generation must surface as a thrown error, never as a silent
/// zero-token stream (CLAUDE.md invariant 6: no silent failures).
final class OllamaClientStreamTests: XCTestCase {
    private func client() -> OllamaClient {
        OllamaClient(baseURL: URL(string: "http://127.0.0.1:11434")!,
                     model: "gpt-oss:20b",
                     session: StubURLProtocol.stubbedSession())
    }

    func testStreamThrowsOnHTTPError() async {
        StubURLProtocol.handler = { req in
            (HTTPURLResponse(url: req.url!, statusCode: 404, httpVersion: nil, headerFields: nil)!,
             Data(#"{"error":"model 'gpt-oss:20b' not found"}"#.utf8))
        }
        do {
            for try await _ in client().stream(system: "s", prompt: "p") {
                XCTFail("no tokens expected from an HTTP 404")
            }
            XCTFail("expected stream to throw on HTTP 404")
        } catch let e as OllamaError {
            XCTAssertEqual(e, .httpStatus(404))
        } catch {
            XCTFail("unexpected error type: \(error)")
        }
    }

    func testStreamThrowsOnMidStreamErrorLine() async {
        StubURLProtocol.handler = { req in
            (HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
             Data("{\"response\":\"Hi\",\"done\":false}\n{\"error\":\"runner crashed\"}\n".utf8))
        }
        var tokens: [String] = []
        do {
            for try await t in client().stream(system: "s", prompt: "p") { tokens.append(t) }
            XCTFail("expected stream to throw on a mid-stream error line")
        } catch let e as OllamaError {
            XCTAssertEqual(e, .server("runner crashed"))
        } catch {
            XCTFail("unexpected error type: \(error)")
        }
        XCTAssertEqual(tokens, ["Hi"], "tokens before the error still stream")
    }

    func testDefaultStreamRequestsLowThinkingEffort() async throws {
        try await assertRequestedThink(call: { client in
            client.stream(system: "s", prompt: "p")
        }, equals: "low")
    }

    func testEffortAwareStreamNormalizesSupportedThinkingEffort() async throws {
        try await assertRequestedThink(call: { client in
            client.stream(system: "s", prompt: "p", effort: " HIGH ")
        }, equals: "high")
    }

    func testEffortAwareStreamFallsBackToLowForUnknownThinkingEffort() async throws {
        try await assertRequestedThink(call: { client in
            client.stream(system: "s", prompt: "p", effort: "maximum")
        }, equals: "low")
    }

    private func assertRequestedThink(
        call: (OllamaClient) -> AsyncThrowingStream<String, Error>,
        equals expected: String
    ) async throws {
        StubURLProtocol.handler = { request in
            let body = try XCTUnwrap(request.bodyStreamData())
            let json = try XCTUnwrap(
                JSONSerialization.jsonObject(with: body) as? [String: Any]
            )
            XCTAssertEqual(json["think"] as? String, expected)
            return (
                HTTPURLResponse(
                    url: request.url!,
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: nil
                )!,
                Data("{\"response\":\"ok\",\"done\":false}\n".utf8)
            )
        }

        var tokens: [String] = []
        for try await token in call(client()) { tokens.append(token) }
        XCTAssertEqual(tokens, ["ok"])
    }
}
