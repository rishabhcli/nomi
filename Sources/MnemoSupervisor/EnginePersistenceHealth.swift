import Foundation

public enum EnginePersistenceHealth {
    private enum WindowScanResult {
        case unreadable
        case noEvent
        case event(succeeded: Bool)
    }

    private enum LinePrefixScanResult {
        case unreadable
        case valid
        case invalid
        case continueScanning
    }

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
        let events = [(failureMarker, false)] + recoveryMarkers.map { ($0, true) }
        let encodedEvents = events.map { (Data($0.0.utf8), $0.1) }
        let overlapBytes = UInt64((encodedEvents.map(\.0.count).max() ?? 1) - 1)
        let maximumWindowBytes = UInt64(Int.max) - overlapBytes
        let windowBytes = max(UInt64(1), min(maximumBytes, maximumWindowBytes))
        var upperBound = end

        // Walk backward until the newest persistence event is found. Each read
        // remains bounded, while an older failure cannot disappear behind
        // unrelated log growth.
        while upperBound > 0 {
            let lowerBound = upperBound > windowBytes ? upperBound - windowBytes : 0
            let readUpperBound = upperBound + min(overlapBytes, end - upperBound)
            let byteCount = Int(readUpperBound - lowerBound)
            let result: WindowScanResult = autoreleasepool {
                guard (try? handle.seek(toOffset: lowerBound)) != nil,
                      let data = try? handle.read(upToCount: byteCount)
                else { return .unreadable }

                var candidates: [(offset: UInt64, succeeded: Bool)] = []
                for (marker, succeeded) in encodedEvents {
                    var searchStart = data.startIndex
                    while searchStart < data.endIndex,
                          let range = data.range(
                              of: marker,
                              in: searchStart ..< data.endIndex
                          )
                    {
                        if range.lowerBound < Int(upperBound - lowerBound) {
                            candidates.append((lowerBound + UInt64(range.lowerBound), succeeded))
                        }
                        searchStart = range.lowerBound + 1
                    }
                }

                for candidate in candidates.sorted(by: { $0.offset > $1.offset }) {
                    if markerStartsTrimmedLine(at: candidate.offset, in: handle) {
                        return .event(succeeded: candidate.succeeded)
                    }
                }
                return .noEvent
            }
            switch result {
            case .unreadable:
                return nil
            case .event(let succeeded):
                return succeeded ? nil : "engine persistence snapshot failed"
            case .noEvent:
                upperBound = lowerBound
            }
        }
        return nil
    }

    private static func markerStartsTrimmedLine(
        at offset: UInt64,
        in handle: FileHandle
    ) -> Bool {
        let scanBytes: UInt64 = 4 * 1024
        var upperBound = offset
        while upperBound > 0 {
            let lowerBound = upperBound > scanBytes ? upperBound - scanBytes : 0
            let result: LinePrefixScanResult = autoreleasepool {
                guard (try? handle.seek(toOffset: lowerBound)) != nil,
                      let data = try? handle.read(upToCount: Int(upperBound - lowerBound))
                else { return .unreadable }
                for byte in data.reversed() {
                    if byte == 0x0A { return .valid }
                    if byte != 0x09, byte != 0x20 { return .invalid }
                }
                return .continueScanning
            }
            switch result {
            case .unreadable, .invalid:
                return false
            case .valid:
                return true
            case .continueScanning:
                upperBound = lowerBound
            }
        }
        return true
    }
}
