import XCTest
@testable import MnemoOrchestrator

private final class FakeVolumeWatcher: @unchecked Sendable, VolumeFileWatching {
    let changes: AsyncStream<FileChangeBatch>
    private let continuation: AsyncStream<FileChangeBatch>.Continuation
    private let lock = NSLock()
    private var started = false
    private var stopped = false

    init() {
        let pair = AsyncStream<FileChangeBatch>.makeStream()
        changes = pair.stream
        continuation = pair.continuation
    }

    func start() throws {
        lock.withLock { started = true }
    }

    func stop() {
        lock.withLock { stopped = true }
    }

    func sendChange() {
        continuation.yield(.init(paths: ["/Volumes/Archive/Changed.md"], requiresFullScan: false))
    }

    var didStop: Bool { lock.withLock { stopped } }
}

private actor RecordingVolumeReconciler: ExternalCorpusReconciling {
    struct Call: Sendable {
        let container: String
        let metadata: [String: String]
    }
    var calls: [Call] = []
    var changeBatches: [FileChangeBatch] = []

    func ingest(
        root: URL,
        container: String,
        uploadLimit: Int,
        extraMetadata: [String: String]
    ) async throws -> ExternalCorpusIngestReport {
        calls.append(.init(container: container, metadata: extraMetadata))
        return .init(
            scan: .init(root: root, candidates: [], skipped: []),
            uploaded: [],
            unchangedCount: 0,
            deferredCount: 0,
            deletedCount: 0,
            failures: []
        )
    }

    func ingestChanges(
        root: URL,
        batch: FileChangeBatch,
        container: String,
        uploadLimit: Int,
        extraMetadata: [String: String]
    ) async throws -> ExternalCorpusIngestReport {
        changeBatches.append(batch)
        return try await ingest(
            root: root,
            container: container,
            uploadLimit: uploadLimit,
            extraMetadata: extraMetadata
        )
    }
}

private actor BlockingVolumeReconciler: ExternalCorpusReconciling {
    var didStart = false
    var wasCancelled = false

    func ingest(
        root: URL,
        container: String,
        uploadLimit: Int,
        extraMetadata: [String: String]
    ) async throws -> ExternalCorpusIngestReport {
        didStart = true
        do {
            try await Task.sleep(for: .seconds(60))
        } catch is CancellationError {
            wasCancelled = true
            throw CancellationError()
        }
        throw CancellationError()
    }
}

private actor IncompleteVolumeReconciler: ExternalCorpusReconciling {
    func ingest(
        root: URL,
        container: String,
        uploadLimit: Int,
        extraMetadata: [String: String]
    ) async throws -> ExternalCorpusIngestReport {
        .init(
            scan: .init(
                root: root,
                candidates: [],
                skipped: [],
                enumerationFailurePaths: [root.appending(path: "Unreadable").path]
            ),
            uploaded: [],
            unchangedCount: 0,
            deferredCount: 0,
            deletedCount: 0,
            failures: []
        )
    }
}

private actor FixedReportVolumeReconciler: ExternalCorpusReconciling {
    let report: ExternalCorpusIngestReport

    init(report: ExternalCorpusIngestReport) {
        self.report = report
    }

    func ingest(
        root: URL,
        container: String,
        uploadLimit: Int,
        extraMetadata: [String: String]
    ) async throws -> ExternalCorpusIngestReport {
        report
    }
}

private actor EmptyRevisionDocumentSource: DocumentIndexing {
    func documentsList(container: String?) async throws -> [DocumentMeta] { [] }
}

private final class VolumeActivityRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [VolumeIndexingActivity] = []

    func append(_ activity: VolumeIndexingActivity) {
        lock.withLock { storage.append(activity) }
    }

    var values: [VolumeIndexingActivity] { lock.withLock { storage } }
}

final class ExternalVolumeIndexCoordinatorTests: XCTestCase {
    private let volume = IndexedVolume(
        id: VolumeID(rawValue: "A-UUID"),
        name: "Archive",
        root: URL(fileURLWithPath: "/Volumes/Archive"),
        isLocal: true,
        isInternal: false,
        isReadOnly: false,
        isReadable: true
    )

    func testInitialAndFSEventReconciliationAlwaysTargetMnemo() async throws {
        let reconciler = RecordingVolumeReconciler()
        let watcher = FakeVolumeWatcher()
        let activities = VolumeActivityRecorder()
        let coordinator = ExternalVolumeIndexCoordinator(
            volume: volume,
            reconciler: reconciler,
            watcher: watcher,
            uploadLimit: 8,
            emit: activities.append
        )

        await coordinator.start()
        try await waitUntil { await reconciler.calls.count == 1 }
        watcher.sendChange()
        try await waitUntil { await reconciler.calls.count == 2 }
        await coordinator.cancel()

        let calls = await reconciler.calls
        XCTAssertEqual(calls.map(\.container), ["mnemo", "mnemo"])
        XCTAssertTrue(calls.allSatisfy {
            $0.metadata[SourceProvenance.sourceKindKey] == SourceKind.file.rawValue
        })
        let changeBatches = await reconciler.changeBatches
        XCTAssertEqual(
            changeBatches,
            [.init(paths: ["/Volumes/Archive/Changed.md"], requiresFullScan: false)]
        )
        XCTAssertEqual(
            activities.values.map(\.phase),
            [.detected, .scanning, .indexing, .ready,
             .scanning, .indexing, .ready, .cancelled]
        )
        XCTAssertTrue(watcher.didStop)
    }

    func testCancellationStopsInFlightReconciliationWithoutErrorActivity() async throws {
        let reconciler = BlockingVolumeReconciler()
        let watcher = FakeVolumeWatcher()
        let activities = VolumeActivityRecorder()
        let coordinator = ExternalVolumeIndexCoordinator(
            volume: volume,
            reconciler: reconciler,
            watcher: watcher,
            uploadLimit: 8,
            emit: activities.append
        )

        await coordinator.start()
        try await waitUntil { await reconciler.didStart }
        await coordinator.cancel()
        let wasCancelled = await reconciler.wasCancelled
        XCTAssertTrue(wasCancelled)

        XCTAssertFalse(activities.values.contains { $0.phase == .error })
        XCTAssertEqual(activities.values.last?.phase, .cancelled)
        XCTAssertTrue(watcher.didStop)
    }

    func testInitialReconciliationWaitsForInteractiveQueryToFinish() async throws {
        let reconciler = RecordingVolumeReconciler()
        let watcher = FakeVolumeWatcher()
        let activities = VolumeActivityRecorder()
        let scheduler = WorkScheduler()
        let token = await scheduler.beginInteractive()
        let coordinator = ExternalVolumeIndexCoordinator(
            volume: volume,
            reconciler: reconciler,
            watcher: watcher,
            uploadLimit: 8,
            scheduler: scheduler,
            emit: activities.append
        )

        await coordinator.start()
        try await Task.sleep(for: .milliseconds(150))
        let callsWhileInteractive = await reconciler.calls.count
        XCTAssertEqual(callsWhileInteractive, 0)
        XCTAssertEqual(activities.values.map(\.phase), [.detected, .scanning])

        await scheduler.endInteractive(token)
        try await waitUntil { await reconciler.calls.count == 1 }
        await coordinator.cancel()
    }

    func testPartialEnumerationCannotReportReady() async throws {
        let watcher = FakeVolumeWatcher()
        let activities = VolumeActivityRecorder()
        let coordinator = ExternalVolumeIndexCoordinator(
            volume: volume,
            reconciler: IncompleteVolumeReconciler(),
            watcher: watcher,
            uploadLimit: 8,
            emit: activities.append
        )

        await coordinator.start()
        try await waitUntil { activities.values.contains { $0.phase == .error } }
        await coordinator.cancel()

        XCTAssertFalse(activities.values.contains { $0.phase == .ready })
    }

    func testUnmountEmitsTypedTerminalActivityAfterWorkStops() async throws {
        let reconciler = BlockingVolumeReconciler()
        let watcher = FakeVolumeWatcher()
        let activities = VolumeActivityRecorder()
        let coordinator = ExternalVolumeIndexCoordinator(
            volume: volume,
            reconciler: reconciler,
            watcher: watcher,
            uploadLimit: 8,
            emit: activities.append
        )

        await coordinator.start()
        try await waitUntil { await reconciler.didStart }
        await coordinator.cancel(reason: .unmounted)

        let wasCancelled = await reconciler.wasCancelled
        XCTAssertTrue(wasCancelled)
        XCTAssertEqual(activities.values.last?.phase, .unmounted)
    }

    func testExternalSameDocumentUploadBumpsRevisionAndInvalidatesCachedAnswer() async throws {
        let index = IngestIndex(docs: EmptyRevisionDocumentSource(), container: "mnemo")
        let cache = AnswerCache()
        let before = await index.corpusRevision
        await cache.store(
            query: "What changed?",
            container: "mnemo",
            corpusRevision: before,
            answer: "old",
            sources: []
        )
        let report = ExternalCorpusIngestReport(
            scan: .init(root: volume.root, candidates: [], skipped: []),
            uploaded: [.init(path: "/Volumes/Archive/Changed.md", documentId: "same-document-id")],
            unchangedCount: 0,
            deferredCount: 0,
            deletedCount: 0,
            failures: []
        )
        let activities = VolumeActivityRecorder()
        let coordinator = ExternalVolumeIndexCoordinator(
            volume: volume,
            reconciler: FixedReportVolumeReconciler(report: report),
            watcher: FakeVolumeWatcher(),
            uploadLimit: 8,
            corpusIndex: index,
            emit: activities.append
        )

        await coordinator.start()
        try await waitUntil { activities.values.contains { $0.phase == .ready } }
        await coordinator.cancel()

        let after = await index.corpusRevision
        XCTAssertEqual(after, before + 1)
        let stale = await cache.lookup(
            query: "What changed?",
            container: "mnemo",
            corpusRevision: after
        )
        XCTAssertNil(stale)
    }

    func testUnchangedExternalScanDoesNotAdvanceCorpusRevision() async throws {
        let index = IngestIndex(docs: EmptyRevisionDocumentSource(), container: "mnemo")
        let report = ExternalCorpusIngestReport(
            scan: .init(root: volume.root, candidates: [], skipped: []),
            uploaded: [],
            unchangedCount: 1,
            deferredCount: 0,
            deletedCount: 0,
            failures: []
        )
        let activities = VolumeActivityRecorder()
        let coordinator = ExternalVolumeIndexCoordinator(
            volume: volume,
            reconciler: FixedReportVolumeReconciler(report: report),
            watcher: FakeVolumeWatcher(),
            uploadLimit: 8,
            corpusIndex: index,
            emit: activities.append
        )

        await coordinator.start()
        try await waitUntil { activities.values.contains { $0.phase == .ready } }
        await coordinator.cancel()

        let revision = await index.corpusRevision
        XCTAssertEqual(revision, 0)
    }

    func testExternalDeletionAdvancesCorpusRevision() async throws {
        let index = IngestIndex(docs: EmptyRevisionDocumentSource(), container: "mnemo")
        let report = ExternalCorpusIngestReport(
            scan: .init(root: volume.root, candidates: [], skipped: []),
            uploaded: [],
            unchangedCount: 0,
            deferredCount: 0,
            deletedCount: 1,
            failures: []
        )
        let activities = VolumeActivityRecorder()
        let coordinator = ExternalVolumeIndexCoordinator(
            volume: volume,
            reconciler: FixedReportVolumeReconciler(report: report),
            watcher: FakeVolumeWatcher(),
            uploadLimit: 8,
            corpusIndex: index,
            emit: activities.append
        )

        await coordinator.start()
        try await waitUntil { activities.values.contains { $0.phase == .ready } }
        await coordinator.cancel()

        let revision = await index.corpusRevision
        XCTAssertEqual(revision, 1)
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
