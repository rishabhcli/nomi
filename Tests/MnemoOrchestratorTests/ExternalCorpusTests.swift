import XCTest
@testable import MnemoOrchestrator

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

    func testRecursivelyPlansOnlySupportedReadableFilesWithinSizeLimit() throws {
        let scanner = ExternalCorpusScanner(policy: .init(
            maxFileBytes: 16,
            supportedExtensions: ["md", "pdf"]
        ))

        let report = try scanner.scan(root: root)

        XCTAssertEqual(
            report.candidates.map(\.relativePath),
            ["Projects/Nested/Orion Notes.md"]
        )
        XCTAssertEqual(report.skippedCount(for: .hidden), 1)
        XCTAssertEqual(report.skippedCount(for: .unsupportedType), 1)
        XCTAssertEqual(report.skippedCount(for: .tooLarge), 1)
    }

    func testFingerprintChangesWhenFileChanges() throws {
        let scanner = ExternalCorpusScanner(policy: .init(
            maxFileBytes: 64,
            supportedExtensions: ["md"]
        ))
        let before = try XCTUnwrap(scanner.scan(root: root).candidates.first)
        try "changed and longer".write(
            to: before.url,
            atomically: true,
            encoding: .utf8
        )
        let after = try XCTUnwrap(scanner.scan(root: root).candidates.first)

        XCTAssertNotEqual(before.fingerprint, after.fingerprint)
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
}
