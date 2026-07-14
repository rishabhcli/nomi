import XCTest
@testable import MnemoOrchestrator

private actor RecordingFileTreeUploader: CorpusFileUploading {
    var containers: [String?] = []
    var metadata: [[String: String]] = []
    func uploadFile(_ fileURL: URL, container: String?, metadata: [String: String]) async throws -> String {
        containers.append(container)
        self.metadata.append(metadata)
        return "doc-\(metadata.count)"
    }
}

/// M13: the whole-machine file crawl plugged in as an `IngestSource` — ingests into
/// the `files` container, stamped with source-kind provenance and the real on-disk
/// path so citations reveal in Finder.
final class FileTreeSourceTests: XCTestCase {
    func testIngestsIntoFilesContainerWithSourceKindProvenance() async throws {
        let root = FileManager.default.temporaryDirectory
            .appending(path: "filetree-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try "hello".write(to: root.appending(path: "Note.md"), atomically: true, encoding: .utf8)

        let uploader = RecordingFileTreeUploader()
        let ingestor = ExternalCorpusIngestor(
            uploader: uploader,
            scanner: ExternalCorpusScanner(policy: .init(maxFileBytes: 1024, supportedExtensions: ["md"])),
            checkpointURL: root.appending(path: "cp.json")
        )
        let source = FileTreeSource(root: root, ingestor: ingestor)

        let report = try await source.sync(limit: 8)

        XCTAssertEqual(report.kind, .file)
        XCTAssertEqual(report.container, "files")
        XCTAssertEqual(report.uploaded, 1)

        let containers = await uploader.containers
        let metadata = await uploader.metadata
        XCTAssertEqual(containers, ["files"], "file source must ingest into the files container")
        XCTAssertEqual(metadata.first?[SourceProvenance.sourceKindKey], "file")
        let originalPath = metadata.first?[ExternalCorpusMetadata.originalPath]
        XCTAssertTrue(originalPath?.hasSuffix("Note.md") ?? false,
                      "the real on-disk path must be recorded for Finder reveal; got \(originalPath ?? "nil")")
    }
}
