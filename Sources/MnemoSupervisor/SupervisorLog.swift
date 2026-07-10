import Foundation
import MnemoCore

/// Aggregates supervisor/engine/ollama local logs for on-call diagnosis.
public enum SupervisorLogAggregator {
    public struct Bundle: Equatable, Sendable {
        public let supervisorLines: [String]
        public let engineLines: [String]
        public let appJSONLLines: [String]
        public let timestamp: String

        public init(supervisorLines: [String], engineLines: [String], appJSONLLines: [String], timestamp: String) {
            self.supervisorLines = supervisorLines
            self.engineLines = engineLines
            self.appJSONLLines = appJSONLLines
            self.timestamp = timestamp
        }
    }

    public static func tail(path: String, maxLines: Int = 50) -> [String] {
        guard let data = FileManager.default.contents(atPath: path),
              let text = String(data: data, encoding: .utf8)
        else { return [] }
        return text.split(separator: "\n", omittingEmptySubsequences: false).suffix(maxLines).map(String.init)
    }

    public static func collect(maxLines: Int = 50) -> Bundle {
        Bundle(
            supervisorLines: tail(path: MnemoLogPaths.supervisorLog, maxLines: maxLines),
            engineLines: tail(path: MnemoLogPaths.engineLog, maxLines: maxLines),
            appJSONLLines: tail(path: MnemoLogPaths.appJSONL, maxLines: maxLines),
            timestamp: ISO8601DateFormatter().string(from: Date())
        )
    }

extension SupervisorLogAggregator.Bundle: Codable {
    public func jsonLine() throws -> String {
        let data = try JSONEncoder().encode(self)
        guard let s = String(data: data, encoding: .utf8) else {
            throw StructuredLogError.encodeFailed
        }
        return s
    }
}
