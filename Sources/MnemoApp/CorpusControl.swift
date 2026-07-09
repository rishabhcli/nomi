// Agent-B audit B-015
import AppKit
import Foundation
import MnemoCore
import MnemoOrchestrator

/// Corpus control (PLAN.md M12.10): add/remove memory-paths, pause indexing,
/// scope folders to containers. Backed by the SMFS mount + engine; pause is a
/// local flag the background sync honors.
@MainActor
final class CorpusControl: ObservableObject {
    @Published var indexingPaused = false
    let config: MnemoConfig
    let smfsPath: String

    init(config: MnemoConfig) {
        self.config = config
        self.smfsPath = NSHomeDirectory() + "/.local/bin/smfs"
    }

    /// Add a memory-path by copying/symlinking a folder into the mount, or by
    /// scoping it via smfs --memory-paths.
    func addPath(_ url: URL, container: String) {
        // A file dropped under the mount is ingested by writing it there.
        let mount = (config.smfs.mountPoint as NSString).expandingTildeInPath
        let dest = URL(fileURLWithPath: mount).appending(path: url.lastPathComponent)
        try? FileManager.default.copyItem(at: url, to: dest)
    }

    func pauseIndexing() { indexingPaused = true }
    func resumeIndexing() { indexingPaused = false }

    /// Scope a folder to a container (work vs personal) via smfs.
    func scope(folder: String, toContainer container: String) {
        _ = try? Subprocess.capture(smfsPath, ["mount", container, "--path", folder,
                                               "--memory-paths", "/", "--api-url",
                                               config.smfs.backingStore.absoluteString])
    }
}
