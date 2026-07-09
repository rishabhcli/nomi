import Foundation

/// Privacy-safe log rotation — archives oversized files locally, never egresses.
public enum LogRotation {
    public static func rotateIfNeeded(path: String, maxBytes: Int) {
        guard maxBytes > 0 else { return }
        let fm = FileManager.default
        guard fm.fileExists(atPath: path),
              let attrs = try? fm.attributesOfItem(atPath: path),
              let size = attrs[.size] as? Int,
              size >= maxBytes
        else { return }
        let archive = path + "." + ISO8601DateFormatter().string(from: Date()) + ".bak"
        try? fm.moveItem(atPath: path, toPath: archive)
        fm.createFile(atPath: path, contents: nil)
    }

    /// Strip document-like payloads from free-form log strings (info level).
    public static func sanitizeInfo(_ message: String) -> String {
        MnemoLogPaths.redactDocumentText(message)
    }
}
