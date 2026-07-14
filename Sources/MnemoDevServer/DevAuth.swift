import Foundation
import MnemoCore

/// Auth for the loopback dev server. Two layers:
///  1. A random per-session token, required on every request (query `token` for
///     GETs that can't set headers — e.g. EventSource — or `X-Mnemo-Token`).
///  2. An Origin/Host loopback check: a webpage you visit could try to POST to
///     127.0.0.1, but the browser stamps its (non-loopback) Origin on such a
///     cross-site request — we reject that. Absent Origin (curl, same-origin
///     navigation) is allowed if Host is loopback.
public enum DevAuth {
    /// 24 random bytes → 48 hex chars.
    public static func newToken() -> String {
        var bytes = [UInt8](repeating: 0, count: 24)
        for i in bytes.indices { bytes[i] = UInt8.random(in: 0...255) }
        return bytes.map { String(format: "%02x", $0) }.joined()
    }

    public static func isAuthorized(_ req: HTTPRequest, token: String) -> Bool {
        guard !token.isEmpty else { return false }
        guard originIsLoopback(req) else { return false }
        let provided = req.query["token"] ?? req.header("x-mnemo-token")
        return provided == token
    }

    static func originIsLoopback(_ req: HTTPRequest) -> Bool {
        if let origin = req.header("origin") {
            guard let host = URL(string: origin)?.host else { return false }
            return isLoopbackHost(host)
        }
        // No Origin header: allow, but the Host (if present) must still be loopback.
        if let hostHeader = req.header("host") {
            let host = hostHeader.split(separator: ":").first.map(String.init) ?? hostHeader
            return isLoopbackHost(host)
        }
        return true
    }
}
