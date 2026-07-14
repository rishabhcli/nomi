import Foundation

/// The outcome of routing a request: a plain response, an SSE upgrade (the
/// transport layer keeps the connection open and streams), or an auth rejection.
public enum RouteOutcome: Sendable {
    case respond(HTTPResponse)
    case sse
    case unauthorized
}

/// Pure request routing — no sockets, so it is fully unit-testable. The
/// transport (`DevServer`) turns `.respond` into a write, `.sse` into a stream,
/// and `.unauthorized` into a 401.
public struct Router: Sendable {
    let token: String
    let dataSource: DashboardDataSource
    /// The dashboard HTML with the session token already substituted.
    let page: String

    public init(token: String, dataSource: DashboardDataSource, page: String) {
        self.token = token
        self.dataSource = dataSource
        self.page = page
    }

    public func handle(_ req: HTTPRequest) async -> RouteOutcome {
        guard DevAuth.isAuthorized(req, token: token) else { return .unauthorized }
        switch (req.method, req.path) {
        case ("GET", "/"):
            return .respond(.html(page))
        case ("GET", "/api/state"):
            let snap = await dataSource.snapshot()
            let body = (try? JSONEncoder().encode(snap)) ?? Data("{}".utf8)
            return .respond(.json(body))
        case ("POST", "/api/ask"):
            let query = (try? JSONDecoder().decode([String: String].self, from: req.body))?["query"] ?? ""
            if !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                await dataSource.ask(query)
            }
            return .respond(HTTPResponse(status: 202))
        case ("GET", "/events"):
            return .sse
        default:
            return .respond(.text("not found", status: 404))
        }
    }
}
