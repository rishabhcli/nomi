import Foundation

/// Server-Sent Events framing. The dashboard consumes `/events` via the browser
/// `EventSource` API; this produces the exact `event:`/`id:`/`data:` wire format.
public enum SSE {
    /// One SSE message. Multi-line `data` is split so each line gets its own
    /// `data:` field (per the SSE spec), and the message ends with a blank line.
    public static func frame(event: String?, data: String, id: String? = nil) -> String {
        var out = ""
        if let event { out += "event: \(event)\n" }
        if let id { out += "id: \(id)\n" }
        for line in data.split(separator: "\n", omittingEmptySubsequences: false) {
            out += "data: \(line)\n"
        }
        out += "\n"
        return out
    }

    /// A comment line — used as a heartbeat to keep the connection alive. The
    /// browser ignores it.
    public static func comment(_ text: String) -> String { ": \(text)\n\n" }
}
