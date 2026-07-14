import Foundation

// MnemoDevServer — the LOCAL, loopback-only developer observability server.
// OFF by default, never shipped. Binds 127.0.0.1 exclusively; serves a
// self-contained (no external assets) dashboard + an SSE feed of the DevTrace
// deep-observability bus. Nothing here egresses.

public enum DevServerInfo {
    public static let version = "0.1.0"
}
