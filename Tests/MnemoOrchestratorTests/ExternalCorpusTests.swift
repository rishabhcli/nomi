import XCTest
@testable import MnemoOrchestrator

private actor ScanCompletionState {
    private(set) var completed = false
    func markCompleted() { completed = true }
}

final class ExternalCorpusScannerTests: XCTestCase {
    private var root: URL!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory
            .appending(path: "external-corpus-\(UUID().uuidString)")
        try FileManager.default.createDirectory(
            at: root.appending(path: "Projects/Nested"),
            withIntermediateDirectories: true
        )
        try "small note".write(
            to: root.appending(path: "Projects/Nested/Orion Notes.md"),
            atomically: true,
            encoding: .utf8
        )
        try "ignore".write(
            to: root.appending(path: ".hidden.md"),
            atomically: true,
            encoding: .utf8
        )
        try "binary".write(
            to: root.appending(path: "Projects/archive.zip"),
            atomically: true,
            encoding: .utf8
        )
        try Data(repeating: 0x41, count: 32).write(
            to: root.appending(path: "Projects/too-large.pdf")
        )
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: root)
    }

    func testRecursivelyPlansOnlySupportedReadableFilesWithinSizeLimit() async throws {
        let scanner = ExternalCorpusScanner(policy: .init(
            maxFileBytes: 16,
            supportedExtensions: ["md", "pdf"]
        ))

        let report = try await scanner.scan(root: root)

        XCTAssertEqual(
            report.candidates.map(\.relativePath),
            ["Projects/Nested/Orion Notes.md"]
        )
        XCTAssertEqual(report.skippedCount(for: .hidden), 1)
        XCTAssertEqual(report.skippedCount(for: .unsupportedType), 1)
        XCTAssertEqual(report.skippedCount(for: .tooLarge), 1)
    }

    func testFingerprintChangesWhenFileChanges() async throws {
        let scanner = ExternalCorpusScanner(policy: .init(
            maxFileBytes: 64,
            supportedExtensions: ["md"]
        ))
        let beforeReport = try await scanner.scan(root: root)
        let before = try XCTUnwrap(beforeReport.candidates.first)
        try "changed and longer".write(
            to: before.url,
            atomically: true,
            encoding: .utf8
        )
        let afterReport = try await scanner.scan(root: root)
        let after = try XCTUnwrap(afterReport.candidates.first)

        XCTAssertNotEqual(before.fingerprint, after.fingerprint)
    }

    func testFingerprintUsesContentWhenSizeAndTimestampAreUnchanged() async throws {
        let scanner = ExternalCorpusScanner(policy: .init(
            maxFileBytes: 64,
            supportedExtensions: ["md"]
        ))
        let file = root.appending(path: "Projects/Nested/Orion Notes.md")
        let beforeReport = try await scanner.scan(root: root)
        let before = try XCTUnwrap(beforeReport.candidates.first)
        try "other note".write(to: file, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes(
            [.modificationDate: before.modifiedAt],
            ofItemAtPath: file.path
        )
        let afterReport = try await scanner.scan(root: root)
        let after = try XCTUnwrap(afterReport.candidates.first)

        XCTAssertEqual(before.byteCount, after.byteCount)
        XCTAssertEqual(before.modifiedAt.timeIntervalSinceReferenceDate,
                       after.modifiedAt.timeIntervalSinceReferenceDate,
                       accuracy: 0.001)
        XCTAssertNotEqual(before.fingerprint, after.fingerprint)
    }

    func testFSEventInvalidationRehashesInPlaceSameMetadataEdit() async throws {
        let scanner = ExternalCorpusScanner(policy: .init(
            maxFileBytes: 64,
            supportedExtensions: ["md"]
        ))
        let file = root.appending(path: "Projects/Nested/Orion Notes.md")
        let beforeReport = try await scanner.scan(root: root)
        let before = try XCTUnwrap(beforeReport.candidates.first)
        let handle = try FileHandle(forWritingTo: file)
        try handle.write(contentsOf: Data("other note".utf8))
        try handle.truncate(atOffset: UInt64(Data("other note".utf8).count))
        try handle.close()
        try FileManager.default.setAttributes(
            [.modificationDate: before.modifiedAt],
            ofItemAtPath: file.path
        )
        scanner.invalidateFingerprints(for: [file.path])
        let afterReport = try await scanner.scan(root: root)
        let after = try XCTUnwrap(afterReport.candidates.first)

        XCTAssertEqual(before.byteCount, after.byteCount)
        XCTAssertNotEqual(before.fingerprint, after.fingerprint)
    }

    func testDefaultPolicySkipsFormatsWithoutADeviceLocalIngestionPath() async throws {
        let unsupported = root.appending(path: "Projects/Slides.pptx")
        try Data("deck".utf8).write(to: unsupported)

        let report = try await ExternalCorpusScanner(
            policy: .init(maxFileBytes: 1_024)
        ).scan(root: root)

        XCTAssertFalse(report.candidates.contains { $0.url == unsupported })
        XCTAssertTrue(report.skipped.contains {
            $0.path == "Projects/Slides.pptx" && $0.reason == .unsupportedType
        })
    }

    func testScanWaitsAtFileBoundaryWhileInteractiveQueryIsRunning() async throws {
        let scheduler = WorkScheduler()
        let token = await scheduler.beginInteractive()
        let scanner = ExternalCorpusScanner(policy: .init(
            maxFileBytes: 1_024,
            supportedExtensions: ["md"]
        ))
        let state = ScanCompletionState()
        let scanRoot = try XCTUnwrap(root)
        let task = Task {
            let report = try await scanner.scan(root: scanRoot, scheduler: scheduler)
            await state.markCompleted()
            return report
        }

        try await Task.sleep(for: .milliseconds(100))
        let completedWhileInteractive = await state.completed
        XCTAssertFalse(completedWhileInteractive)
        await scheduler.endInteractive(token)

        let report = try await task.value
        XCTAssertEqual(report.candidates.count, 1)
    }
}

private actor RecordingCorpusUploader: CorpusFileUploading {
    var paths: [String] = []
    var metadata: [[String: String]] = []

    func uploadFile(
        _ fileURL: URL,
        container: String?,
        metadata: [String: String]
    ) async throws -> String {
        paths.append(fileURL.path)
        self.metadata.append(metadata)
        return "doc-\(paths.count)"
    }
}

private actor RecordingCorpusDeleter: CorpusDocumentDeleting {
    var ids: [String] = []

    func deleteDocument(_ documentId: String) async throws {
        ids.append(documentId)
    }
}

private actor SlowCorpusUploader: CorpusFileUploading {
    var paths: [String] = []

    func uploadFile(
        _ fileURL: URL,
        container: String?,
        metadata: [String: String]
    ) async throws -> String {
        try await Task.sleep(for: .seconds(2))
        paths.append(fileURL.path)
        return "doc-\(paths.count)"
    }
}

private actor StableIDCorpusUploader: CorpusFileUploading {
    func uploadFile(
        _ fileURL: URL,
        container: String?,
        metadata: [String: String]
    ) async throws -> String {
        "stable-doc"
    }
}

final class ExternalCorpusIngestorTests: XCTestCase {
    func testCheckpointSkipsUnchangedFilesAndRetainsOriginalPath() async throws {
        let root = FileManager.default.temporaryDirectory
            .appending(path: "external-ingest-\(UUID().uuidString)")
        let checkpoint = root.appending(path: "checkpoint.json")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let file = root.appending(path: "Find Me.md")
        try "The launch code is ORION-7429.".write(to: file, atomically: true, encoding: .utf8)

        let uploader = RecordingCorpusUploader()
        let scanner = ExternalCorpusScanner(policy: .init(
            maxFileBytes: 1_024,
            supportedExtensions: ["md"]
        ))
        let ingestor = ExternalCorpusIngestor(
            uploader: uploader,
            scanner: scanner,
            checkpointURL: checkpoint
        )

        let first = try await ingestor.ingest(root: root, container: "mnemo", uploadLimit: 8)
        let second = try await ingestor.ingest(root: root, container: "mnemo", uploadLimit: 8)
        let uploadedPaths = await uploader.paths
        let uploadedMetadata = await uploader.metadata

        XCTAssertEqual(first.uploaded.count, 1)
        XCTAssertEqual(second.unchangedCount, 1)
        XCTAssertEqual(uploadedPaths.count, 1)
        XCTAssertEqual(
            uploadedMetadata.first?[ExternalCorpusMetadata.originalPath],
            file.path
        )
    }

    func testReconcileDeletesDocumentsWhoseFilesDisappeared() async throws {
        let root = FileManager.default.temporaryDirectory
            .appending(path: "external-delete-\(UUID().uuidString)")
        let checkpoint = root.appending(path: "checkpoint.json")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let file = root.appending(path: "Retire Me.md")
        try "temporary fact".write(to: file, atomically: true, encoding: .utf8)
        let uploader = RecordingCorpusUploader()
        let deleter = RecordingCorpusDeleter()
        let ingestor = ExternalCorpusIngestor(
            uploader: uploader,
            deleter: deleter,
            scanner: ExternalCorpusScanner(policy: .init(
                maxFileBytes: 1_024,
                supportedExtensions: ["md"]
            )),
            checkpointURL: checkpoint
        )

        _ = try await ingestor.ingest(root: root, container: "mnemo", uploadLimit: 8)
        try FileManager.default.removeItem(at: file)
        let report = try await ingestor.ingest(root: root, container: "mnemo", uploadLimit: 8)

        XCTAssertEqual(report.deletedCount, 1)
        let deletedIds = await deleter.ids
        XCTAssertEqual(deletedIds, ["doc-1"])
    }

    func testCancellationStopsBoundedUpload() async throws {
        let root = FileManager.default.temporaryDirectory
            .appending(path: "external-cancel-\(UUID().uuidString)")
        let checkpoint = root.appending(path: "checkpoint.json")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try "one".write(to: root.appending(path: "One.md"), atomically: true, encoding: .utf8)
        try "two".write(to: root.appending(path: "Two.md"), atomically: true, encoding: .utf8)
        let uploader = SlowCorpusUploader()
        let ingestor = ExternalCorpusIngestor(
            uploader: uploader,
            scanner: ExternalCorpusScanner(policy: .init(
                maxFileBytes: 1_024,
                supportedExtensions: ["md"]
            )),
            checkpointURL: checkpoint
        )
        let task = Task {
            try await ingestor.ingest(root: root, container: "mnemo", uploadLimit: 1)
        }
        try await Task.sleep(for: .milliseconds(25))
        task.cancel()

        do {
            _ = try await task.value
            XCTFail("Expected cancellation")
        } catch is CancellationError {
            // Expected: unmount cancellation must leave the batch unfinished.
        }
        let uploadedPaths = await uploader.paths
        XCTAssertTrue(uploadedPaths.isEmpty)
    }

    func testStableUpsertIDIsNotDeletedWhenContentChanges() async throws {
        let root = FileManager.default.temporaryDirectory
            .appending(path: "external-stable-id-\(UUID().uuidString)")
        let checkpoint = root.appending(path: "checkpoint.json")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let file = root.appending(path: "Profile.md")
        try "first value".write(to: file, atomically: true, encoding: .utf8)
        let deleter = RecordingCorpusDeleter()
        let ingestor = ExternalCorpusIngestor(
            uploader: StableIDCorpusUploader(),
            deleter: deleter,
            scanner: ExternalCorpusScanner(policy: .init(
                maxFileBytes: 1_024,
                supportedExtensions: ["md"]
            )),
            checkpointURL: checkpoint
        )

        _ = try await ingestor.ingest(root: root, container: "mnemo", uploadLimit: 8)
        try "second valu".write(to: file, atomically: true, encoding: .utf8)
        _ = try await ingestor.ingest(root: root, container: "mnemo", uploadLimit: 8)

        let deletedIds = await deleter.ids
        XCTAssertTrue(deletedIds.isEmpty)
    }

    func testDeferredBatchesReuseOneScanSnapshot() async throws {
        let root = FileManager.default.temporaryDirectory
            .appending(path: "external-batches-\(UUID().uuidString)")
        let checkpoint = root.appending(path: "checkpoint.json")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        for name in ["A.md", "B.md", "C.md"] {
            try name.write(to: root.appending(path: name), atomically: true, encoding: .utf8)
        }
        let uploader = RecordingCorpusUploader()
        let ingestor = ExternalCorpusIngestor(
            uploader: uploader,
            scanner: .init(policy: .init(maxFileBytes: 1_024, supportedExtensions: ["md"])),
            checkpointURL: checkpoint
        )

        var report = try await ingestor.ingest(root: root, container: "mnemo", uploadLimit: 1)
        try "late".write(
            to: root.appending(path: "Late.md"),
            atomically: true,
            encoding: .utf8
        )
        while report.deferredCount > 0 {
            report = try await ingestor.ingest(root: root, container: "mnemo", uploadLimit: 1)
        }

        let pathsAfterBatches = await uploader.paths
        XCTAssertEqual(pathsAfterBatches.count, 3)
        let next = try await ingestor.ingest(root: root, container: "mnemo", uploadLimit: 8)
        XCTAssertEqual(next.uploaded.map(\.path), [root.appending(path: "Late.md").path])
    }

    func testIncrementalReconciliationOnlyScansReportedPaths() async throws {
        let root = FileManager.default.temporaryDirectory
            .appending(path: "external-incremental-\(UUID().uuidString)")
        let checkpoint = root.appending(path: "checkpoint.json")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let reported = root.appending(path: "Reported.md")
        let silent = root.appending(path: "Silent.md")
        try "one".write(to: reported, atomically: true, encoding: .utf8)
        try "one".write(to: silent, atomically: true, encoding: .utf8)
        let uploader = RecordingCorpusUploader()
        let ingestor = ExternalCorpusIngestor(
            uploader: uploader,
            scanner: .init(policy: .init(maxFileBytes: 1_024, supportedExtensions: ["md"])),
            checkpointURL: checkpoint
        )
        _ = try await ingestor.ingest(root: root, container: "mnemo", uploadLimit: 8)
        try "two".write(to: reported, atomically: true, encoding: .utf8)
        try "two".write(to: silent, atomically: true, encoding: .utf8)

        let report = try await ingestor.ingestChanges(
            root: root,
            batch: .init(paths: [reported.path], requiresFullScan: false),
            container: "mnemo",
            uploadLimit: 8,
            extraMetadata: [:]
        )

        XCTAssertEqual(report.uploaded.map(\.path), [reported.path])
        let allPaths = await uploader.paths
        XCTAssertEqual(allPaths.filter { $0 == silent.path }.count, 1)
    }
}
