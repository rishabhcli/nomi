import Foundation

public enum OllamaError: Error, Equatable {
    case notHTTP
    case httpStatus(Int)
    case server(String)   // {"error": "..."} line in the stream
}

public enum OllamaLine {
    struct Chunk: Decodable {
        let response: String?
        let done: Bool?
        let error: String?
    }
    private static func decode(_ line: String) -> Chunk? {
        let t = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty, let data = t.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(Chunk.self, from: data)
    }
    /// Returns the token in a streamed JSON line, or nil for empty/done/garbage lines.
    public static func parse(_ line: String) -> String? {
        guard let c = decode(line), let r = c.response, !r.isEmpty else { return nil }
        return r
    }
    /// Returns the server-reported error in a streamed line, if any.
    public static func error(_ line: String) -> String? {
        guard let c = decode(line), let e = c.error, !e.isEmpty else { return nil }
        return e
    }
}

public protocol Generating: Sendable {
    func stream(system: String, prompt: String) -> AsyncThrowingStream<String, Error>
}

public struct OllamaClient: Generating {
    let baseURL: URL
    let model: String
    let keepAlive: String
    let session: URLSession

    public init(baseURL: URL, model: String, keepAlive: String = "30m", session: URLSession = .shared) {
        self.baseURL = baseURL
        self.model = model
        self.keepAlive = keepAlive
        self.session = session
    }

    struct Body: Encodable {
        let model: String
        let system: String
        let prompt: String
        let stream = true
        let keep_alive: String
    }

    public func stream(system: String, prompt: String) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    var url = baseURL
                    url.append(path: "/api/generate")
                    var r = URLRequest(url: url)
                    r.httpMethod = "POST"
                    r.timeoutInterval = 600
                    r.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    r.httpBody = try JSONEncoder().encode(Body(model: model, system: system, prompt: prompt, keep_alive: keepAlive))
                    let (bytes, resp) = try await session.bytes(for: r)
                    // A failed generation must throw, never end as a silent
                    // zero-token stream (invariant: no silent failures).
                    guard let http = resp as? HTTPURLResponse else { throw OllamaError.notHTTP }
                    guard http.statusCode == 200 else { throw OllamaError.httpStatus(http.statusCode) }
                    for try await line in bytes.lines {
                        if Task.isCancelled { break }
                        if let err = OllamaLine.error(line) { throw OllamaError.server(err) }
                        if let tok = OllamaLine.parse(line) { continuation.yield(tok) }
                    }
                    continuation.finish()
                } catch { continuation.finish(throwing: error) }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}
