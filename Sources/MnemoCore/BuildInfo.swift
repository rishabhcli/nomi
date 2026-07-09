import Foundation

public enum BuildInfo {
    /// Version from git tag, MNEMO_VERSION env, or Package default.
    public static var version: String {
        if let v = ProcessInfo.processInfo.environment["MNEMO_VERSION"], !v.isEmpty { return v }
        if let v = gitDescribe(), !v.isEmpty { return v }
        return Mnemo.version
    }

    public static var buildStamp: String {
        if let s = ProcessInfo.processInfo.environment["MNEMO_BUILD_STAMP"], !s.isEmpty { return s }
        return ISO8601DateFormatter().string(from: Date())
    }

    private static func gitDescribe() -> String? {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        proc.arguments = ["describe", "--tags", "--always", "--dirty"]
        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError = Pipe()
        guard (try? proc.run()) != nil else { return nil }
        proc.waitUntilExit()
        guard proc.terminationStatus == 0 else { return nil }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
