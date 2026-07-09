import Foundation

public struct IngestGate {
    let retriever: Retrieving
    public init(retriever: Retrieving) { self.retriever = retriever }

    public func writeFile(_ contents: String, to url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try contents.write(to: url, atomically: true, encoding: .utf8)
    }

    /// Polls search until the probe query returns any result, or the timeout elapses.
    public func waitUntilSearchable(probe query: String, timeout: Duration) async -> Bool {
        let deadline = ContinuousClock.now.advanced(by: timeout)
        while ContinuousClock.now < deadline {
            if let hits = try? await retriever.search(SearchRequest(q: query)), !hits.isEmpty { return true }
            try? await Task.sleep(for: .milliseconds(200))
        }
        return false
    }
}
