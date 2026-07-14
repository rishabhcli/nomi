import CoreServices
import Foundation

public enum FSEventsWatcherError: Error, Equatable, Sendable {
    case streamCreationFailed(String)
    case streamStartFailed(String)
}

private func mnemoFSEventsCallback(
    _ stream: ConstFSEventStreamRef,
    _ clientInfo: UnsafeMutableRawPointer?,
    _ eventCount: Int,
    _ eventPaths: UnsafeMutableRawPointer,
    _ eventFlags: UnsafePointer<FSEventStreamEventFlags>,
    _ eventIDs: UnsafePointer<FSEventStreamEventId>
) {
    guard let clientInfo else { return }
    let watcher = Unmanaged<FSEventsVolumeWatcher>.fromOpaque(clientInfo)
        .takeUnretainedValue()
    let array = Unmanaged<CFArray>.fromOpaque(eventPaths).takeUnretainedValue()
    let paths = array as? [String] ?? []
    let flags = (0..<eventCount).map { eventFlags[$0] }
    watcher.receive(paths: paths, flags: flags)
}

/// Per-volume FSEvents stream. Native callbacks arrive on a private serial queue;
/// paths are coalesced for a short interval before one reconciliation is emitted.
public final class FSEventsVolumeWatcher: @unchecked Sendable, VolumeFileWatching {
    public let changes: AsyncStream<FileChangeBatch>

    private let continuation: AsyncStream<FileChangeBatch>.Continuation
    private let root: URL
    private let sinceEventID: FSEventStreamEventId
    private let debounceSeconds: TimeInterval
    private let queue: DispatchQueue
    private var stream: FSEventStreamRef?
    private var accumulator = FileChangeAccumulator()
    private var debounceWork: DispatchWorkItem?
    private var isStarted = false

    public init(
        root: URL,
        sinceEventID: FSEventStreamEventId = FSEventsGetCurrentEventId(),
        debounceSeconds: TimeInterval = 0.5
    ) {
        self.root = root.standardizedFileURL
        self.sinceEventID = sinceEventID
        self.debounceSeconds = debounceSeconds
        self.queue = DispatchQueue(
            label: "ai.mnemo.fsevents.\(UUID().uuidString)",
            qos: .utility
        )
        let pair = AsyncStream<FileChangeBatch>.makeStream(
            // One pending reconciliation is enough. If it is replaced while the
            // coordinator is busy, `yieldBatch` converts the replacement to a
            // full scan, preserving correctness without queuing repeated scans.
            bufferingPolicy: .bufferingNewest(1)
        )
        changes = pair.stream
        continuation = pair.continuation
        continuation.onTermination = { [weak self] _ in self?.stop() }
    }

    deinit {
        stopLocked()
        continuation.finish()
    }

    public func start() throws {
        try queue.sync {
            guard !isStarted else { return }
            var context = FSEventStreamContext(
                version: 0,
                info: Unmanaged.passUnretained(self).toOpaque(),
                retain: nil,
                release: nil,
                copyDescription: nil
            )
            let flags = FSEventStreamCreateFlags(
                kFSEventStreamCreateFlagUseCFTypes
                    | kFSEventStreamCreateFlagNoDefer
                    | kFSEventStreamCreateFlagWatchRoot
                    | kFSEventStreamCreateFlagFileEvents
                    | kFSEventStreamCreateFlagIgnoreSelf
            )
            guard let created = FSEventStreamCreate(
                nil,
                mnemoFSEventsCallback,
                &context,
                [root.path] as CFArray,
                sinceEventID,
                0.2,
                flags
            ) else {
                throw FSEventsWatcherError.streamCreationFailed(root.path)
            }
            stream = created
            FSEventStreamSetDispatchQueue(created, queue)
            guard FSEventStreamStart(created) else {
                FSEventStreamInvalidate(created)
                FSEventStreamRelease(created)
                stream = nil
                throw FSEventsWatcherError.streamStartFailed(root.path)
            }
            isStarted = true
        }
    }

    public func stop() {
        queue.sync { stopLocked() }
    }

    fileprivate func receive(
        paths: [String],
        flags: [FSEventStreamEventFlags]
    ) {
        let rescanFlags = FSEventStreamEventFlags(
            kFSEventStreamEventFlagMustScanSubDirs
                | kFSEventStreamEventFlagUserDropped
                | kFSEventStreamEventFlagKernelDropped
                | kFSEventStreamEventFlagEventIdsWrapped
                | kFSEventStreamEventFlagRootChanged
        )
        let requiresFullScan = flags.contains { ($0 & rescanFlags) != 0 }
        record(paths: paths, requiresFullScan: requiresFullScan)
    }

    private func record(paths: [String], requiresFullScan: Bool) {
        accumulator.record(paths: paths, requiresFullScan: requiresFullScan)
        debounceWork?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.flush() }
        debounceWork = work
        queue.asyncAfter(deadline: .now() + debounceSeconds, execute: work)
    }

    private func flush() {
        guard let batch = accumulator.drain() else { return }
        yieldBatch(batch)
    }

    private func yieldBatch(_ batch: FileChangeBatch) {
        switch continuation.yield(batch) {
        case .dropped:
            // The current batch was enqueued, but an older set of paths was
            // discarded. Replace the just-enqueued incremental work with a full
            // reconciliation so every dropped change is recovered.
            guard !batch.requiresFullScan else { return }
            _ = continuation.yield(FileChangeBatch(paths: [], requiresFullScan: true))
        case .enqueued, .terminated:
            break
        @unknown default:
            break
        }
    }

    /// Drives the same delivery path in tests without constructing a kernel
    /// FSEvents stream or waiting on the debounce clock.
    func receiveForTesting(paths: [String]) {
        queue.sync {
            accumulator.record(paths: paths, requiresFullScan: false)
            flush()
        }
    }

    private func stopLocked() {
        guard let stream else { return }
        debounceWork?.cancel()
        debounceWork = nil
        FSEventStreamStop(stream)
        FSEventStreamInvalidate(stream)
        FSEventStreamRelease(stream)
        self.stream = nil
        isStarted = false
    }
}
