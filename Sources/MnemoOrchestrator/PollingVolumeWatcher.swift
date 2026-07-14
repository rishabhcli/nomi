import Foundation

/// Compatibility watcher for local filesystems that cannot provide a reliable
/// FSEvents stream. The coordinator still performs its first crawl immediately;
/// this watcher requests bounded checkpointed full reconciliation afterward.
public final class PollingVolumeWatcher: @unchecked Sendable, DemandDrivenVolumeFileWatching {
    public let changes: AsyncStream<FileChangeBatch>

    private let continuation: AsyncStream<FileChangeBatch>.Continuation
    private let root: URL
    private let interval: Duration
    private let lock = NSLock()
    private var task: Task<Void, Never>?
    private var isStarted = false

    public init(root: URL, interval: Duration = .seconds(30)) {
        self.root = root.standardizedFileURL
        self.interval = interval
        let pair = AsyncStream<FileChangeBatch>.makeStream(
            bufferingPolicy: .bufferingNewest(1)
        )
        changes = pair.stream
        continuation = pair.continuation
        continuation.onTermination = { [weak self] _ in self?.stop() }
    }

    deinit {
        stop()
        continuation.finish()
    }

    public func start() throws {
        lock.lock()
        defer { lock.unlock() }
        isStarted = true
    }

    public func reconciliationDidFinish() {
        lock.lock()
        guard isStarted, task == nil else {
            lock.unlock()
            return
        }
        let interval = self.interval
        task = Task.detached(priority: .utility) { [weak self] in
            do {
                try await Task.sleep(for: interval)
            } catch {
                return
            }
            self?.fire()
        }
        lock.unlock()
    }

    private func fire() {
        lock.lock()
        guard isStarted else {
            task = nil
            lock.unlock()
            return
        }
        task = nil
        lock.unlock()
        continuation.yield(FileChangeBatch(
            paths: [root.path],
            reason: .periodicFullScan
        ))
    }

    public func stop() {
        lock.lock()
        let running = task
        task = nil
        isStarted = false
        lock.unlock()
        running?.cancel()
    }
}
