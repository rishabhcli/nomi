import Foundation

public enum EnginePersistenceHealth {
    private static let failureMarker = "[storage] Snapshot failed"
    private static let recoveryMarkers = [
        "[storage] Snapshot:",
        "[storage] Snapshot (shutdown):",
        "[storage] Loaded snapshot",
        "[storage] No snapshot found",
    ]

    public static func failureReason(in log: String) -> String? {
        var latestEventSucceeded: Bool?
        for rawLine in log.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.hasPrefix(failureMarker) {
                latestEventSucceeded = false
            } else if recoveryMarkers.contains(where: line.hasPrefix) {
                latestEventSucceeded = true
            }
        }
        return latestEventSucceeded == false ? "engine persistence snapshot failed" : nil
    }

    public static func failureReason(
        at path: String,
        maximumBytes: UInt64 = 512 * 1024
    ) -> String? {
        guard let handle = try? FileHandle(forReadingFrom: URL(fileURLWithPath: path)) else {
            return nil
        }
        defer { try? handle.close() }
        guard let end = try? handle.seekToEnd() else { return nil }
        let start = end > maximumBytes ? end - maximumBytes : 0
        try? handle.seek(toOffset: start)
        guard let data = try? handle.readToEnd() else { return nil }
        let log = String(decoding: data, as: UTF8.self)
        return failureReason(in: log)
    }
}
