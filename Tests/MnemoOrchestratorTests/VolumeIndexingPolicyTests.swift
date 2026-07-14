import XCTest
@testable import MnemoOrchestrator

final class VolumeIndexingPolicyTests: XCTestCase {
    private func volume(
        id: String? = "A-UUID",
        local: Bool = true,
        internalVolume: Bool = false,
        readOnly: Bool = false,
        readable: Bool = true,
        browsable: Bool = true,
        path: String = "/Volumes/Archive"
    ) -> IndexedVolume {
        IndexedVolume(
            id: id.map(VolumeID.init(rawValue:)),
            name: "Archive",
            root: URL(fileURLWithPath: path),
            isLocal: local,
            isInternal: internalVolume,
            isReadOnly: readOnly,
            isReadable: readable,
            isBrowsable: browsable
        )
    }

    func testOnlyReadableLocalExternalVolumesWithUUIDAreEligible() {
        XCTAssertEqual(VolumeEligibility.evaluate(volume()), .eligible)
        XCTAssertEqual(VolumeEligibility.evaluate(volume(readOnly: true)), .eligible)
        XCTAssertEqual(VolumeEligibility.evaluate(volume(id: nil)), .ineligible(.missingUUID))
        XCTAssertEqual(VolumeEligibility.evaluate(volume(local: false)), .ineligible(.notLocal))
        XCTAssertEqual(VolumeEligibility.evaluate(volume(internalVolume: true)), .ineligible(.internalVolume))
        XCTAssertEqual(VolumeEligibility.evaluate(volume(readable: false)), .ineligible(.unreadable))
        XCTAssertEqual(VolumeEligibility.evaluate(volume(browsable: false)), .ineligible(.notBrowsable))
    }

    func testRegistryStartsOneCoordinatorPerUUIDAndStopsItOnUnmount() throws {
        let first = volume(path: "/Volumes/Archive")
        let duplicateIdentity = volume(path: "/Volumes/Archive Renamed")
        let id = try XCTUnwrap(first.id)
        var registry = VolumeIndexRegistry()

        XCTAssertEqual(registry.apply(.mounted(first)), .start(first))
        XCTAssertNil(registry.apply(.mounted(duplicateIdentity)))
        XCTAssertEqual(registry.activeVolumeIDs, [id])
        XCTAssertEqual(registry.apply(.unmounted(id)), .stop(id))
        XCTAssertTrue(registry.activeVolumeIDs.isEmpty)
        XCTAssertNil(registry.apply(.unmounted(id)))
    }

    func testRegistryIgnoresIneligibleMounts() {
        var registry = VolumeIndexRegistry()

        XCTAssertNil(registry.apply(.mounted(volume(internalVolume: true))))
        XCTAssertTrue(registry.activeVolumeIDs.isEmpty)
    }

    func testActivityStatePolicyAllowsInitialIndexAndLaterReconciliation() {
        XCTAssertTrue(VolumeActivityPolicy.allowsTransition(from: nil, to: .detected))
        XCTAssertTrue(VolumeActivityPolicy.allowsTransition(from: .detected, to: .scanning))
        XCTAssertTrue(VolumeActivityPolicy.allowsTransition(from: .scanning, to: .indexing))
        XCTAssertTrue(VolumeActivityPolicy.allowsTransition(from: .indexing, to: .ready))
        XCTAssertTrue(VolumeActivityPolicy.allowsTransition(from: .ready, to: .scanning))
        XCTAssertTrue(VolumeActivityPolicy.allowsTransition(from: .ready, to: .error))
        XCTAssertTrue(VolumeActivityPolicy.allowsTransition(from: .error, to: .scanning))
        XCTAssertFalse(VolumeActivityPolicy.allowsTransition(from: nil, to: .ready))
        XCTAssertFalse(VolumeActivityPolicy.allowsTransition(from: .detected, to: .ready))
    }

    func testFileChangeBatchCoalescesPathsAndRetainsFullScanSignal() {
        var accumulator = FileChangeAccumulator()
        accumulator.record(paths: ["/Volumes/A/one.md", "/Volumes/A/two.md"], requiresFullScan: false)
        accumulator.record(paths: ["/Volumes/A/one.md"], requiresFullScan: true)

        XCTAssertEqual(
            accumulator.drain(),
            FileChangeBatch(
                paths: ["/Volumes/A/one.md", "/Volumes/A/two.md"],
                requiresFullScan: true
            )
        )
        XCTAssertNil(accumulator.drain())
    }

    func testFSEventsBufferOverflowForcesAFullScanRecoveryBatch() async {
        let watcher = FSEventsVolumeWatcher(
            root: URL(fileURLWithPath: "/Volumes/Archive"),
            debounceSeconds: 0
        )

        watcher.receiveForTesting(paths: ["/Volumes/Archive/one.md"])
        watcher.receiveForTesting(paths: ["/Volumes/Archive/two.md"])

        var iterator = watcher.changes.makeAsyncIterator()
        let retained = await iterator.next()

        XCTAssertEqual(retained?.requiresFullScan, true,
                       "a dropped path batch must degrade to a full-volume reconciliation")
    }

    func testWatcherStrategyUsesPollingForFilesystemsWithoutNativeFSEvents() {
        XCTAssertEqual(VolumeWatcherPolicy.strategy(forFileSystem: "apfs"), .fsevents)
        XCTAssertEqual(VolumeWatcherPolicy.strategy(forFileSystem: "hfs"), .fsevents)
        XCTAssertEqual(VolumeWatcherPolicy.strategy(forFileSystem: "exfat"), .periodicFullScan)
        XCTAssertEqual(VolumeWatcherPolicy.strategy(forFileSystem: "msdos"), .periodicFullScan)
        XCTAssertEqual(VolumeWatcherPolicy.strategy(forFileSystem: nil), .periodicFullScan)
    }

    func testPollingWatcherEmitsAFullReconciliationBatch() async throws {
        let root = URL(fileURLWithPath: "/Volumes/Archive")
        let watcher = PollingVolumeWatcher(root: root, interval: .milliseconds(5))

        try watcher.start()
        watcher.reconciliationDidFinish()
        var iterator = watcher.changes.makeAsyncIterator()
        let batch = await iterator.next()
        watcher.stop()

        XCTAssertEqual(batch, FileChangeBatch(paths: [root.path], reason: .periodicFullScan))
    }

    func testPollingWatcherDoesNotQueueCatchUpScans() async throws {
        let watcher = PollingVolumeWatcher(
            root: URL(fileURLWithPath: "/Volumes/Archive"),
            interval: .milliseconds(20)
        )
        try watcher.start()
        watcher.reconciliationDidFinish()
        var iterator = watcher.changes.makeAsyncIterator()
        _ = await iterator.next()

        try await Task.sleep(for: .milliseconds(70))
        let clock = ContinuousClock()
        let started = clock.now
        watcher.reconciliationDidFinish()
        _ = await iterator.next()
        let elapsed = started.duration(to: clock.now)
        watcher.stop()

        XCTAssertGreaterThanOrEqual(elapsed, .milliseconds(15),
                                    "a slow scan must not leave a catch-up tick queued")
    }

    func testPeriodicFullScanPreservesFingerprintsWhileEventLossInvalidatesThem() {
        XCTAssertEqual(
            FileChangeBatch(paths: [], reason: .periodicFullScan).reason,
            .periodicFullScan
        )
        XCTAssertEqual(
            FileChangeBatch(paths: [], requiresFullScan: true).reason,
            .eventLossFullScan
        )
    }

    func testWorkspaceObserverReadsTheKernelFilesystemName() throws {
        let name = try XCTUnwrap(WorkspaceVolumeObserver.fileSystemType(
            at: URL(fileURLWithPath: NSTemporaryDirectory())
        ))

        XCTAssertEqual(name, name.lowercased())
        XCTAssertFalse(name.contains(" "))
    }
}
