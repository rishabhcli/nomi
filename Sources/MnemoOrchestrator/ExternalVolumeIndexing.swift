import Foundation

public protocol VolumeIndexCoordinating: Sendable {
    func start() async
    func cancel(reason: VolumeIndexStopReason) async
}

public enum VolumeIndexStopReason: Equatable, Sendable {
    case unmounted
    case cancelled
}

public extension VolumeIndexCoordinating {
    func cancel() async {
        await cancel(reason: .cancelled)
    }
}

/// Owns one bounded checkpointed crawl and one FSEvents stream for a volume.
/// Every reconciliation targets `mnemo`, matching the app's current query scope.
public actor ExternalVolumeIndexCoordinator: VolumeIndexCoordinating {
    public static let container = "mnemo"

    private let volume: IndexedVolume
    private let reconciler: ExternalCorpusReconciling
    private let watcher: VolumeFileWatching
    private let uploadLimit: Int
    private let scheduler: WorkScheduler?
    private let corpusIndex: IngestIndex?
    private let retryDelays: [Duration]
    private let emit: @Sendable (VolumeIndexingActivity) -> Void
    private var task: Task<Void, Never>?

    public init(
        volume: IndexedVolume,
        reconciler: ExternalCorpusReconciling,
        watcher: VolumeFileWatching,
        uploadLimit: Int,
        scheduler: WorkScheduler? = nil,
        corpusIndex: IngestIndex? = nil,
        retryDelays: [Duration] = [
            .milliseconds(250),
            .seconds(1),
            .seconds(2),
        ],
        emit: @escaping @Sendable (VolumeIndexingActivity) -> Void
    ) {
        self.volume = volume
        self.reconciler = reconciler
        self.watcher = watcher
        self.uploadLimit = max(1, uploadLimit)
        self.scheduler = scheduler
        self.corpusIndex = corpusIndex
        self.retryDelays = retryDelays
        self.emit = emit
    }

    public func start() {
        guard task == nil else { return }
        task = Task { [weak self] in await self?.run() }
    }

    public func cancel(reason: VolumeIndexStopReason) async {
        guard let running = task else {
            emit(reason == .unmounted ? .unmounted(volume) : .cancelled(volume))
            return
        }
        running.cancel()
        watcher.stop()
        await running.value
        task = nil
        emit(reason == .unmounted ? .unmounted(volume) : .cancelled(volume))
    }

    private func run() async {
        guard !Task.isCancelled else { return }
        emit(.detected(volume))

        do {
            // `FSEventsVolumeWatcher` captures its starting event ID when it is
            // constructed. Crawl first so even a blocking/failed watcher cannot
            // suppress the initial index, then replay events from that ID.
            try await reconcileWithRetries(changeBatch: nil)
            do {
                try watcher.start()
            } catch {
                try await recoverWatcher(after: error)
            }
            (watcher as? any DemandDrivenVolumeFileWatching)?.reconciliationDidFinish()
            for await batch in watcher.changes {
                try Task.checkCancellation()
                try await reconcileWithRetries(changeBatch: batch)
                (watcher as? any DemandDrivenVolumeFileWatching)?.reconciliationDidFinish()
            }
        } catch is CancellationError {
            // Unmount is an expected terminal path; it should not surface as an error.
        } catch {
            emit(.error(volume, message: String(describing: error)))
        }
        watcher.stop()
    }

    private func recoverWatcher(after initialError: any Error) async throws {
        var lastError = initialError
        for delay in retryDelays {
            try Task.checkCancellation()
            try await Task.sleep(for: delay)
            do {
                try watcher.start()
                return
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                lastError = error
            }
        }
        throw lastError
    }

    private func reconcileWithRetries(changeBatch: FileChangeBatch?) async throws {
        var nextRetry = 0
        while true {
            do {
                try await reconcile(
                    changeBatch: changeBatch,
                    announceScanning: nextRetry == 0
                )
                return
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                try Task.checkCancellation()
                guard nextRetry < retryDelays.count else { throw error }
                let delay = retryDelays[nextRetry]
                nextRetry += 1
                try await Task.sleep(for: delay)
            }
        }
    }

    private func reconcile(
        changeBatch: FileChangeBatch?,
        announceScanning: Bool
    ) async throws {
        let isSilentPeriodicPass = changeBatch?.reason == .periodicFullScan
        if announceScanning, !isSilentPeriodicPass { emit(.scanning(volume)) }
        var finalIndexed = 0
        var hadFailures = false
        var scansWereComplete = true
        var isFirstPass = true
        var emittedProgress = false

        while true {
            try Task.checkCancellation()
            try await waitForInteractiveWork()
            let metadata = SourceProvenance.stamp(.file)
            let report: ExternalCorpusIngestReport
            if isFirstPass, let changeBatch {
                report = try await reconciler.ingestChanges(
                    root: volume.root,
                    batch: changeBatch,
                    container: Self.container,
                    uploadLimit: uploadLimit,
                    extraMetadata: metadata
                )
            } else {
                report = try await reconciler.ingest(
                    root: volume.root,
                    container: Self.container,
                    uploadLimit: uploadLimit,
                    extraMetadata: metadata
                )
            }
            isFirstPass = false
            if !report.uploaded.isEmpty || report.deletedCount > 0 {
                await corpusIndex?.recordExternalMutation()
            }
            let hasVisibleWork = !report.uploaded.isEmpty || report.deletedCount > 0
                || report.deferredCount > 0 || !report.failures.isEmpty || !report.scan.isComplete
            if !isSilentPeriodicPass || hasVisibleWork {
                emit(.indexing(
                    volume,
                    uploaded: report.uploaded.count,
                    unchanged: report.unchangedCount,
                    deleted: report.deletedCount,
                    deferred: report.deferredCount
                ))
                emittedProgress = true
            }
            finalIndexed = report.scan.candidates.count - report.failures.count
            hadFailures = hadFailures || !report.failures.isEmpty
            scansWereComplete = scansWereComplete && report.scan.isComplete
            guard report.deferredCount > 0 else { break }
            try Task.checkCancellation()
            await Task.yield()
        }

        if hadFailures || !scansWereComplete {
            emit(.error(volume, message: "Some files could not be indexed locally."))
        } else if !isSilentPeriodicPass || emittedProgress {
            emit(.ready(volume, indexed: max(0, finalIndexed)))
        }
    }

    /// Keep disk crawling below the live answer path. A scan already in flight
    /// finishes its current bounded unit, then every subsequent pass waits.
    private func waitForInteractiveWork() async throws {
        guard let scheduler else { return }
        while await scheduler.shouldBackgroundYield {
            try Task.checkCancellation()
            try await Task.sleep(for: .milliseconds(100))
        }
    }
}

/// App-facing service: consumes the native mount stream, applies pure eligibility
/// policy, and owns exactly one coordinator for each active volume UUID.
public actor ExternalVolumeIndexingService {
    public nonisolated let activities: AsyncStream<VolumeIndexingActivity>

    private let activityContinuation: AsyncStream<VolumeIndexingActivity>.Continuation
    private let observer: VolumeObserving
    private let makeCoordinator: @Sendable (
        IndexedVolume,
        @escaping @Sendable (VolumeIndexingActivity) -> Void
    ) -> any VolumeIndexCoordinating
    private var registry = VolumeIndexRegistry()
    private var coordinators: [VolumeID: any VolumeIndexCoordinating] = [:]
    private var eventTask: Task<Void, Never>?

    public init(
        observer: VolumeObserving,
        makeCoordinator: @escaping @Sendable (
            IndexedVolume,
            @escaping @Sendable (VolumeIndexingActivity) -> Void
        ) -> any VolumeIndexCoordinating
    ) {
        self.observer = observer
        self.makeCoordinator = makeCoordinator
        let pair = AsyncStream<VolumeIndexingActivity>.makeStream(
            bufferingPolicy: .bufferingNewest(256)
        )
        activities = pair.stream
        activityContinuation = pair.continuation
    }

    /// Production composition. No remote endpoints are constructed here: the
    /// supplied EngineClient is already pinned to the validated loopback URL.
    public init(
        engine: EngineClient,
        observer: VolumeObserving = WorkspaceVolumeObserver(),
        checkpointDirectory: URL = URL(fileURLWithPath: NSHomeDirectory())
            .appending(path: ".supermemory/volume-checkpoints"),
        maxFileBytes: Int64 = 50 * 1_024 * 1_024,
        uploadLimit: Int = 64,
        debounceSeconds: TimeInterval = 0.5,
        scheduler: WorkScheduler? = nil,
        corpusIndex: IngestIndex? = nil
    ) {
        self.init(observer: observer) { volume, emit in
            let id = volume.id?.rawValue ?? "missing"
            let scanner = ExternalCorpusScanner(policy: .init(maxFileBytes: maxFileBytes))
            let localFirst = LocalFirstCorpusUploader(
                directUploader: engine,
                creator: engine,
                scheduler: scheduler
            )
            let ingestor = ExternalCorpusIngestor(
                uploader: localFirst,
                deleter: engine,
                scanner: scanner,
                checkpointURL: checkpointDirectory.appending(path: "\(id).json"),
                scheduler: scheduler
            )
            let watcher: any VolumeFileWatching = switch VolumeWatcherPolicy.strategy(
                forFileSystem: volume.fileSystemType
            ) {
            case .fsevents:
                FSEventsVolumeWatcher(
                    root: volume.root,
                    debounceSeconds: debounceSeconds
                )
            case .periodicFullScan:
                PollingVolumeWatcher(root: volume.root)
            }
            return ExternalVolumeIndexCoordinator(
                volume: volume,
                reconciler: ingestor,
                watcher: watcher,
                uploadLimit: uploadLimit,
                scheduler: scheduler,
                corpusIndex: corpusIndex,
                emit: emit
            )
        }
    }

    public func start() {
        guard eventTask == nil else { return }
        let events = observer.events
        eventTask = Task { [weak self] in
            for await event in events {
                guard !Task.isCancelled else { break }
                await self?.handle(event)
            }
        }
        observer.start()
    }

    public func stop() async {
        let runningEvents = eventTask
        runningEvents?.cancel()
        eventTask = nil
        observer.stop()
        if let runningEvents { await runningEvents.value }
        let active = Array(coordinators.values)
        coordinators.removeAll()
        for coordinator in active { await coordinator.cancel(reason: .cancelled) }
        registry = VolumeIndexRegistry()
    }

    private func handle(_ event: VolumeEvent) async {
        guard let action = registry.apply(event) else { return }
        switch action {
        case .start(let volume):
            guard let id = volume.id else { return }
            let coordinator = makeCoordinator(volume) { [activityContinuation] activity in
                activityContinuation.yield(activity)
            }
            coordinators[id] = coordinator
            await coordinator.start()
        case .stop(let id):
            guard let coordinator = coordinators.removeValue(forKey: id) else { return }
            await coordinator.cancel(reason: .unmounted)
        }
    }
}
