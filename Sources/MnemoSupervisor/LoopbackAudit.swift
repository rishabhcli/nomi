import Foundation

public struct ListeningSocket: Equatable, Sendable {
    public let command: String
    public let pid: Int
    public let address: String
    public init(command: String, pid: Int, address: String) {
        self.command = command
        self.pid = pid
        self.address = address
    }
}

public enum LoopbackAudit {
    /// Known mnemo stack ports: engine 6767, ollama 11434, Rivet 6420, smfs 11111.
    public static let knownPorts: Set<Int> = [6767, 11434, 6420, 11111]

    public static func isMnemoOwned(_ socket: ListeningSocket) -> Bool {
        let cmd = socket.command.lowercased()
        let prefixes = ["ollama", "supermemory-server", "supermem", "smfs", "mnemo", "rivet"]
        if prefixes.contains(where: { cmd.hasPrefix($0) }) { return true }
        if let port = Int(socket.address.split(separator: ":").last ?? "") {
            return knownPorts.contains(port)
        }
        return false
    }

    public static func parseLSOF(_ text: String) -> [ListeningSocket] {
        var out: [ListeningSocket] = []
        for line in text.split(separator: "\n").dropFirst() { // drop header
            let cols = line.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
            // The NAME column is the last host:port token — `127.0.0.1:6767`,
            // `[::1]:6767`, or `*:8080` (lsof's spelling of 0.0.0.0/[::]).
            // Dropping any of them would silently pass the loopback audit.
            guard cols.count >= 9, let pid = Int(cols[1]),
                  let addr = cols.last(where: { $0.contains(":") })
            else { continue }
            out.append(ListeningSocket(command: cols[0], pid: pid, address: addr))
        }
        return out
    }
    public static func nonLoopback(_ sockets: [ListeningSocket]) -> [ListeningSocket] {
        sockets.filter { !isLoopbackAddress($0.address) }
    }

    public static func isLoopbackAddress(_ address: String) -> Bool {
        address.hasPrefix("127.0.0.1:") || address.hasPrefix("[::1]:") || address.hasPrefix("localhost:")
    }
}
