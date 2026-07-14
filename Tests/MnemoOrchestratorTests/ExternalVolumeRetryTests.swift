import XCTest
@testable import MnemoOrchestrator

private enum RetryTestError: Error {
    case transient
}

private final class RetryVolumeWatcher: @unchecked Sendable, VolumeFileWatching {
    let changes: AsyncStream<FileChangeBatch>
    private let lock = NSLock()
    private var startFailuresRemaining: Int
    private var startAttempts = 0
    private var stopped = false

    init(startFailures: Int = 0) {
        startFailuresRemaining = startFailures
        changes = AsyncStream { _ in }
    }

    func start() throws {
        let shouldFail = lock.withLock {
            startAttempts += 1
            guard startFailuresRemaining > 0 else { return false }
            startFailuresRemaining -= 1
            return true
        }
        if shouldFail { throw RetryTestError.transient }
    }

    func stop() { lock.withLock { stopped = true } }

    var startAttemptCount: Int { lock.withLock { startAttempts } }
    var didStop: Bool { lock.withLock { stopped } }
}

private actor RetryRecordingReconciler: ExternalCorpusReconciling {
    private(set) var callCount = 0

    func ingest(
        root: URL,
        container: String,
        uploadLimit: Int,
        extraMetadata: [String: String]
    ) async throws -> ExternalCorpusIngestReport {
        callCount += 1
        return .init(
            scan: .init(root: root, candidates: [], skipped: []),
            uploaded: [],
            unchangedCount: 0,
            deferredCount: 0,
            deletedCount: 0,
            failures: []
        )
    }
}

private actor FlakyRetryReconciler: ExternalCorpusReconciling {
    private let failuresBeforeSuccess: Int
    private(set) var attemptCount = 0

    init(failuresBeforeSuccess: Int) {
        self.failuresBeforeSuccess = failuresBeforeSuccess
    }

    func ingest(
        root: URL,
        container: String,
        uploadLimit: Int,
        extraMetadata: [String: String]
    ) async throws -> ExternalCorpusIngestReport {
        attemptCount += 1
        if attemptCount <= failuresBeforeSuccess { throw RetryTestError.transient }
        return .init(
            scan: .init(root: root, candidates: [], skipped: []),
            uploaded: [],
            unchangedCount: 0,
            deferredCount: 0,
            deletedCount: 0,
            failures: []
        )
    }
}

private final class RetryActivityRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [VolumeIndexingActivity] = []

    func append(_ activity: VolumeIndexingActivity) {
        lock.withLock { storage.append(activity) }
    }

    var values: [VolumeIndexingActivity] { lock.withLock { storage } }
}

final class ExternalVolumeRetryTests: XCTestCase {
    private let volume = IndexedVolume(
        id: VolumeID(rawValue: "A-UUID"),
        name: "Archive",
        root: URL(fileURLWithPath: "/Volumes/Archive"),
        isLocal: true,
        isInternal: false,
        isReadOnly: false,
        isReadable: true
    )

    func testInitialCrawlRunsBeforePermanentWatcherFailureSurfaces() async throws {
        let reconciler = RetryRecordingReconciler()
        let watcher = RetryVolumeWatcher(startFailures: 10)
        let activities = RetryActivityRecorder()
        let coordinator = makeCoordinator(reconciler, watcher, [.zero, .zero], activities)

        await coordinator.start()
        try await waitUntil { activities.values.contains { $0.phase == .error } }

        let reconcileCallCount = await reconciler.callCount
        XCTAssertEqual(reconcileCallCount, 1)
        XCTAssertEqual(watcher.startAttemptCount, 3)
        XCTAssertEqual(
            activities.values.map(\.phase),
            [.detected, .scanning, .indexing, .ready, .error]
        )
        await coordinator.cancel()
    }

    func testTransientWatcherStartupFailureRecoversWithoutError() async throws {
        let reconciler = RetryRecordingReconciler()
        let watcher = RetryVolumeWatcher(startFailures: 2)
        let activities = RetryActivityRecorder()
        let coordinator = makeCoordinator(reconciler, watcher, [.zero, .zero], activities)

        await coordinator.start()
        try await waitUntil { watcher.startAttemptCount == 3 }

        let reconcileCallCount = await reconciler.callCount
        XCTAssertEqual(reconcileCallCount, 1)
        XCTAssertFalse(activities.values.contains { $0.phase == .error })
        await coordinator.cancel()
    }

    func testTransientReconciliationFailureRetriesToReadyWithoutError() async throws {
        let reconciler = FlakyRetryReconciler(failuresBeforeSuccess: 2)
        let watcher = RetryVolumeWatcher()
        let activities = RetryActivityRecorder()
        let coordinator = makeCoordinator(reconciler, watcher, [.zero, .zero], activities)

        await coordinator.start()
        try await waitUntil { activities.values.contains { $0.phase == .ready } }

        let attemptCount = await reconciler.attemptCount
        XCTAssertEqual(attemptCount, 3)
        XCTAssertFalse(activities.values.contains { $0.phase == .error })
        await coordinator.cancel()
    }

    func testRepeatedStartDoesNotDuplicateTheRetryLoop() async throws {
        let reconciler = FlakyRetryReconciler(failuresBeforeSuccess: 1)
        let watcher = RetryVolumeWatcher()
        let activities = RetryActivityRecorder()
        let coordinator = makeCoordinator(reconciler, watcher, [.zero], activities)

        await coordinator.start()
        await coordinator.start()
        try await waitUntil { activities.values.contains { $0.phase == .ready } }

        let attemptCount = await reconciler.attemptCount
        XCTAssertEqual(attemptCount, 2)
        XCTAssertEqual(watcher.startAttemptCount, 1)
        XCTAssertEqual(activities.values.filter { $0.phase == .detected }.count, 1)
        await coordinator.cancel()
    }

    func testReconciliationErrorSurfacesOnlyAfterRetryBudgetIsExhausted() async throws {
        let reconciler = FlakyRetryReconciler(failuresBeforeSuccess: 10)
        let watcher = RetryVolumeWatcher()
        let activities = RetryActivityRecorder()
        let coordinator = makeCoordinator(reconciler, watcher, [.zero, .zero], activities)

        await coordinator.start()
        try await waitUntil { activities.values.contains { $0.phase == .error } }

        let attemptCount = await reconciler.attemptCount
        XCTAssertEqual(attemptCount, 3)
        XCTAssertEqual(activities.values.filter { $0.phase == .error }.count, 1)
        XCTAssertFalse(activities.values.contains { $0.phase == .ready })
        await coordinator.cancel()
    }

    func testCancellationInterruptsRetryBackoffWithoutError() async throws {
        let reconciler = FlakyRetryReconciler(failuresBeforeSuccess: 10)
        let watcher = RetryVolumeWatcher()
        let activities = RetryActivityRecorder()
        let coordinator = makeCoordinator(reconciler, watcher, [.seconds(60)], activities)

        await coordinator.start()
        try await waitUntil { await reconciler.attemptCount == 1 }
        await coordinator.cancel()

        let attemptCount = await reconciler.attemptCount
        XCTAssertEqual(attemptCount, 1)
        XCTAssertFalse(activities.values.contains { $0.phase == .error })
        XCTAssertEqual(activities.values.last?.phase, .cancelled)
        XCTAssertTrue(watcher.didStop)
    }

    func testPollingPassIsSilentWhenTheDiskIsUnchanged() async throws {
        let reconciler = RetryRecordingReconciler()
        let watcher = PollingVolumeWatcher(root: volume.root, interval: .milliseconds(5))
        let activities = RetryActivityRecorder()
        let coordinator = ExternalVolumeIndexCoordinator(
            volume: volume,
            reconciler: reconciler,
            watcher: watcher,
            uploadLimit: 8,
            retryDelays: [],
            emit: activities.append
        )

        await coordinator.start()
        try await waitUntil { await reconciler.callCount >= 2 }
        await coordinator.cancel()

        XCTAssertEqual(
            activities.values.map(\.phase),
            [.detected, .scanning, .indexing, .ready, .cancelled]
        )
    }

    func testUnmountCancelsPollingSleepPromptly() async throws {
        let watcher = PollingVolumeWatcher(root: volume.root, interval: .seconds(60))
        let activities = RetryActivityRecorder()
        let coordinator = ExternalVolumeIndexCoordinator(
            volume: volume,
            reconciler: RetryRecordingReconciler(),
            watcher: watcher,
            uploadLimit: 8,
            retryDelays: [],
            emit: activities.append
        )

        await coordinator.start()
        try await waitUntil { activities.values.contains { $0.phase == .ready } }
        let clock = ContinuousClock()
        let started = clock.now
        await coordinator.cancel(reason: .unmounted)
        let elapsed = started.duration(to: clock.now)

        XCTAssertLessThan(elapsed, .seconds(1))
        XCTAssertEqual(activities.values.last?.phase, .unmounted)
    }

    private func makeCoordinator(
        _ reconciler: some ExternalCorpusReconciling,
        _ watcher: RetryVolumeWatcher,
        _ retryDelays: [Duration],
        _ activities: RetryActivityRecorder
    ) -> ExternalVolumeIndexCoordinator {
        ExternalVolumeIndexCoordinator(
            volume: volume,
            reconciler: reconciler,
            watcher: watcher,
            uploadLimit: 8,
            retryDelays: retryDelays,
            emit: activities.append
        )
    }

    private func waitUntil(
        timeoutIterations: Int = 200,
        _ predicate: @escaping @Sendable () async -> Bool
    ) async throws {
        for _ in 0..<timeoutIterations {
            if await predicate() { return }
            try await Task.sleep(for: .milliseconds(5))
        }
        XCTFail("Timed out waiting for asynchronous state")
    }
}
