import Foundation

/// One JSON object per query — local only, never egresses.
/// Info level must not contain document body text (CLAUDE.md §4).
public struct QueryLogEntry: Codable, Equatable, Sendable {
    public var queryId: String
    public var timestamp: String
    public var routeIntent: String?
    public var effortTier: String?
    public var retrievalHopCount: Int?
    public var firstTokenMs: Int?
    public var totalMs: Int?
    public var egressBlockedCount: Int?
    public var verificationPassRate: Double?
    public var contextTokenCount: Int?
    public var modelId: String?
    public var terminalState: String?
    public var level: String

    public init(queryId: String = UUID().uuidString, level: String = "info") {
        self.queryId = queryId
        self.timestamp = ISO8601DateFormatter().string(from: Date())
        self.level = level
    }

    public func redacted() -> QueryLogEntry {
        var copy = self
        copy.level = level
        return copy
    }

    public func jsonLine() throws -> String {
        let data = try JSONEncoder().encode(self)
        guard let s = String(data: data, encoding: .utf8) else {
            throw StructuredLogError.encodeFailed
        }
        return s
    }
}

public enum StructuredLogError: Error, Equatable {
    case encodeFailed
    case writeFailed(String)
}

/// Protocol for query-path observability without coupling to QueryService internals.
public protocol QueryLogSink: Sendable {
    func emit(_ entry: QueryLogEntry) async
}

public struct FileQueryLogSink: QueryLogSink {
    let path: String
    public init(path: String = MnemoLogPaths.appJSONL) { self.path = path }

    public func emit(_ entry: QueryLogEntry) async {
        guard let line = try? entry.redacted().jsonLine() else { return }
        MnemoLogPaths.appendLine(line + "\n", to: path)
    }
}

public struct NullQueryLogSink: QueryLogSink {
    public init() {}
    public func emit(_ entry: QueryLogEntry) async {}
}

public enum MnemoLogPaths {
    public static var logsDir: String {
        NSHomeDirectory() + "/Library/Logs/Mnemo"
    }
    public static var appJSONL: String { logsDir + "/app.jsonl" }
    public static var supervisorLog: String { logsDir + "/supervisor.log" }
    public static var engineLog: String { logsDir + "/engine.log" }

    public static func ensureLogsDir() {
        try? FileManager.default.createDirectory(atPath: logsDir, withIntermediateDirectories: true)
    }

    public static func appendLine(_ line: String, to path: String) {
        ensureLogsDir()
        if !FileManager.default.fileExists(atPath: path) {
            FileManager.default.createFile(atPath: path, contents: nil)
        }
        guard let h = FileHandle(forWritingAtPath: path) else { return }
        defer { try? h.close() }
        try? h.seekToEnd()
        if let d = line.data(using: .utf8) { try? h.write(contentsOf: d) }
    }

    /// Redact document-like content from log strings (privacy).
    public static func redactDocumentText(_ s: String, maxLen: Int = 120) -> String {
        if s.count <= maxLen { return s }
        return String(s.prefix(maxLen)) + "…"
    }
}
