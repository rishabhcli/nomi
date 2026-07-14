import AppKit
import Darwin
import Foundation

/// Native mounted-volume source. Notification observers are installed before
/// enumerating current mounts so a disk cannot slip through the startup gap.
public final class WorkspaceVolumeObserver: @unchecked Sendable, VolumeObserving {
    public let events: AsyncStream<VolumeEvent>

    private let continuation: AsyncStream<VolumeEvent>.Continuation
    private let queue = DispatchQueue(label: "ai.mnemo.volume-observer")
    private var observerTokens: [NSObjectProtocol] = []
    private var idsByPath: [String: VolumeID] = [:]
    private var isStarted = false

    private static let resourceKeys: Set<URLResourceKey> = [
        .volumeUUIDStringKey,
        .volumeNameKey,
        .volumeIsLocalKey,
        .volumeIsInternalKey,
        .volumeIsReadOnlyKey,
        .volumeIsBrowsableKey,
    ]

    public init() {
        let pair = AsyncStream<VolumeEvent>.makeStream(bufferingPolicy: .bufferingNewest(256))
        events = pair.stream
        continuation = pair.continuation
        continuation.onTermination = { [weak self] _ in self?.stop() }
    }

    deinit {
        let center = NSWorkspace.shared.notificationCenter
        for token in observerTokens { center.removeObserver(token) }
        continuation.finish()
    }

    public func start() {
        queue.async { [self] in
            guard !isStarted else { return }
            isStarted = true
            installObservers()
            enumerateMountedVolumes()
        }
    }

    public func stop() {
        queue.async { [self] in
            guard isStarted else { return }
            isStarted = false
            let center = NSWorkspace.shared.notificationCenter
            for token in observerTokens { center.removeObserver(token) }
            observerTokens.removeAll()
            idsByPath.removeAll()
        }
    }

    private func installObservers() {
        let center = NSWorkspace.shared.notificationCenter
        observerTokens.append(center.addObserver(
            forName: NSWorkspace.didMountNotification,
            object: nil,
            queue: nil
        ) { [weak self] notification in
            guard let self, let url = Self.volumeURL(from: notification) else { return }
            queue.async { [self] in handleMounted(url) }
        })
        observerTokens.append(center.addObserver(
            forName: NSWorkspace.didUnmountNotification,
            object: nil,
            queue: nil
        ) { [weak self] notification in
            guard let self, let url = Self.volumeURL(from: notification) else { return }
            queue.async { [self] in handleUnmounted(url) }
        })
    }

    private func enumerateMountedVolumes() {
        let urls = FileManager.default.mountedVolumeURLs(
            includingResourceValuesForKeys: Array(Self.resourceKeys),
            options: [.skipHiddenVolumes]
        ) ?? []
        for url in urls { publishMounted(url) }
    }

    private func handleMounted(_ url: URL) {
        guard isStarted else { return }
        publishMounted(url)
    }

    private func handleUnmounted(_ url: URL) {
        guard isStarted else { return }
        let path = url.standardizedFileURL.path
        guard let id = idsByPath.removeValue(forKey: path) else { return }
        continuation.yield(.unmounted(id))
    }

    private func publishMounted(_ url: URL) {
        guard let volume = Self.describe(url) else { return }
        if let id = volume.id { idsByPath[volume.root.path] = id }
        continuation.yield(.mounted(volume))
    }

    private static func volumeURL(from notification: Notification) -> URL? {
        notification.userInfo?[NSWorkspace.volumeURLUserInfoKey] as? URL
    }

    static func describe(_ rawURL: URL) -> IndexedVolume? {
        let url = rawURL.standardizedFileURL
        guard let values = try? url.resourceValues(forKeys: resourceKeys) else { return nil }
        return IndexedVolume(
            id: values.volumeUUIDString.map(VolumeID.init(rawValue:)),
            name: values.volumeName ?? url.lastPathComponent,
            root: url,
            isLocal: values.volumeIsLocal ?? false,
            isInternal: values.volumeIsInternal ?? true,
            isReadOnly: values.volumeIsReadOnly ?? true,
            isReadable: FileManager.default.isReadableFile(atPath: url.path),
            isBrowsable: values.volumeIsBrowsable ?? false,
            fileSystemType: fileSystemType(at: url)
        )
    }

    /// Kernel filesystem name, not localized UI text. Unknown formats fail to
    /// polling in `VolumeWatcherPolicy`.
    static func fileSystemType(at url: URL) -> String? {
        var info = statfs()
        let status: Int32 = url.withUnsafeFileSystemRepresentation { path in
            guard let path else { return -1 }
            return statfs(path, &info)
        }
        guard status == 0 else { return nil }
        return withUnsafePointer(to: &info.f_fstypename) { tuple in
            tuple.withMemoryRebound(to: CChar.self, capacity: Int(MFSNAMELEN)) {
                String(cString: $0).lowercased()
            }
        }
    }
}
