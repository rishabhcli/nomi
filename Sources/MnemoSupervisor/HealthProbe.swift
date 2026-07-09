import Foundation

public protocol HealthProbe: Sendable {
    func isUp(_ url: URL) async -> Bool
}

public struct HTTPHealthProbe: HealthProbe {
    let session: URLSession
    public init(session: URLSession = .shared) { self.session = session }
    public func isUp(_ url: URL) async -> Bool {
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        req.timeoutInterval = 2
        do {
            let (_, resp) = try await session.data(for: req)
            guard let http = resp as? HTTPURLResponse else { return false }
            return http.statusCode < 500
        } catch { return false }
    }
}
