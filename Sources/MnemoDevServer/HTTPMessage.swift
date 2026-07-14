import Foundation

/// A parsed HTTP/1.1 request. Header keys are lowercased; `header(_:)` is the
/// case-insensitive accessor. `parse` returns nil for anything without a
/// complete header block (the caller keeps reading until it does).
public struct HTTPRequest: Sendable, Equatable {
    public let method: String
    public let path: String
    public let query: [String: String]
    public let headers: [String: String]
    public let body: Data

    public init(method: String, path: String, query: [String: String],
                headers: [String: String], body: Data) {
        self.method = method
        self.path = path
        self.query = query
        self.headers = headers
        self.body = body
    }

    public func header(_ name: String) -> String? { headers[name.lowercased()] }

    /// Content-Length as declared by the request, if any (used to know when the
    /// body is fully received).
    public var contentLength: Int { header("content-length").flatMap(Int.init) ?? 0 }

    public static func parse(_ data: Data) -> HTTPRequest? {
        guard let sep = data.range(of: Data("\r\n\r\n".utf8)) else { return nil }
        let head = Data(data[..<sep.lowerBound])
        let body = Data(data[sep.upperBound...])
        guard let headStr = String(data: head, encoding: .utf8) else { return nil }
        var lines = headStr.components(separatedBy: "\r\n")
        guard !lines.isEmpty else { return nil }

        let request = lines.removeFirst().split(separator: " ")
        guard request.count >= 2 else { return nil }
        let method = String(request[0])
        let target = String(request[1])

        var path = target
        var query: [String: String] = [:]
        if let q = target.firstIndex(of: "?") {
            path = String(target[..<q])
            for pair in target[target.index(after: q)...].split(separator: "&") {
                let kv = pair.split(separator: "=", maxSplits: 1)
                let key = percentDecode(String(kv[0]))
                query[key] = kv.count > 1 ? percentDecode(String(kv[1])) : ""
            }
        }

        var headers: [String: String] = [:]
        for line in lines where !line.isEmpty {
            guard let colon = line.firstIndex(of: ":") else { continue }
            let name = line[..<colon].trimmingCharacters(in: .whitespaces).lowercased()
            let value = line[line.index(after: colon)...].trimmingCharacters(in: .whitespaces)
            headers[name] = value
        }
        return HTTPRequest(method: method, path: path, query: query, headers: headers, body: body)
    }

    private static func percentDecode(_ s: String) -> String {
        s.replacingOccurrences(of: "+", with: " ").removingPercentEncoding ?? s
    }
}

/// A response ready to serialize onto a connection. `serialize()` always stamps
/// Content-Length so the client knows the body bounds.
public struct HTTPResponse: Sendable {
    public var status: Int
    public var headers: [String: String]
    public var body: Data

    public init(status: Int = 200, headers: [String: String] = [:], body: Data = Data()) {
        self.status = status
        self.headers = headers
        self.body = body
    }

    public func serialize() -> Data {
        var h = headers
        h["Content-Length"] = String(body.count)
        var text = "HTTP/1.1 \(status) \(Self.reason(status))\r\n"
        for (k, v) in h { text += "\(k): \(v)\r\n" }
        text += "\r\n"
        var out = Data(text.utf8)
        out.append(body)
        return out
    }

    public static func json(_ body: Data, status: Int = 200) -> HTTPResponse {
        HTTPResponse(status: status, headers: ["Content-Type": "application/json; charset=utf-8"], body: body)
    }

    public static func html(_ s: String) -> HTTPResponse {
        HTTPResponse(status: 200, headers: ["Content-Type": "text/html; charset=utf-8"], body: Data(s.utf8))
    }

    public static func text(_ s: String, status: Int = 200) -> HTTPResponse {
        HTTPResponse(status: status, headers: ["Content-Type": "text/plain; charset=utf-8"], body: Data(s.utf8))
    }

    static func reason(_ code: Int) -> String {
        switch code {
        case 200: return "OK"
        case 202: return "Accepted"
        case 400: return "Bad Request"
        case 401: return "Unauthorized"
        case 403: return "Forbidden"
        case 404: return "Not Found"
        case 405: return "Method Not Allowed"
        case 500: return "Internal Server Error"
        default: return "OK"
        }
    }
}
