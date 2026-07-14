import XCTest
@testable import MnemoOrchestrator

private actor DirectUploadRecorder: CorpusFileUploading {
    var paths: [String] = []

    func uploadFile(
        _ fileURL: URL,
        container: String?,
        metadata: [String: String]
    ) async throws -> String {
        paths.append(fileURL.path)
        return "direct"
    }
}

private actor CreatedDocumentRecorder: DocumentCreating {
    struct Call: Sendable {
        let content: String
        let customId: String?
        let container: String?
        let metadata: [String: String]
    }

    var calls: [Call] = []

    func createDocument(
        content: String,
        customId: String?,
        container: String?,
        metadata: [String: String]
    ) async throws -> String {
        calls.append(.init(
            content: content,
            customId: customId,
            container: container,
            metadata: metadata
        ))
        return "local-text"
    }
}

private actor ExtractionCallRecorder {
    private(set) var calls = 0
    func record() { calls += 1 }
}

final class LocalFirstCorpusUploaderTests: XCTestCase {
    func testPDFIsExtractedLocallyAndNeverSentToDirectUploader() async throws {
        let direct = DirectUploadRecorder()
        let creator = CreatedDocumentRecorder()
        let uploader = LocalFirstCorpusUploader(
            directUploader: direct,
            creator: creator,
            extract: { _ in "Local PDF text" }
        )
        let url = URL(fileURLWithPath: "/Volumes/Archive/Plan.pdf")

        let id = try await uploader.uploadFile(
            url,
            container: "mnemo",
            metadata: [ExternalCorpusMetadata.originalPath: url.path]
        )

        XCTAssertEqual(id, "local-text")
        let directPaths = await direct.paths
        XCTAssertTrue(directPaths.isEmpty)
        let calls = await creator.calls
        XCTAssertEqual(calls.count, 1)
        XCTAssertEqual(calls[0].container, "mnemo")
        XCTAssertEqual(calls[0].metadata[MediaCompanion.extractionKey], "on-device")
        XCTAssertTrue(calls[0].content.contains("Local PDF text"))
        XCTAssertNotNil(calls[0].customId)
    }

    func testPlainTextUsesDirectLoopbackUpload() async throws {
        let direct = DirectUploadRecorder()
        let creator = CreatedDocumentRecorder()
        let uploader = LocalFirstCorpusUploader(
            directUploader: direct,
            creator: creator,
            extract: { _ in XCTFail("Plain text should not need media extraction"); return nil }
        )
        let url = URL(fileURLWithPath: "/Volumes/Archive/Notes.md")

        let id = try await uploader.uploadFile(url, container: "mnemo", metadata: [:])

        XCTAssertEqual(id, "direct")
        let directPaths = await direct.paths
        XCTAssertEqual(directPaths, [url.path])
        let calls = await creator.calls
        XCTAssertTrue(calls.isEmpty)
    }

    func testUnknownBinaryTypeFailsClosedWithoutDirectUpload() async throws {
        let direct = DirectUploadRecorder()
        let creator = CreatedDocumentRecorder()
        let uploader = LocalFirstCorpusUploader(
            directUploader: direct,
            creator: creator,
            extract: { _ in nil }
        )
        let url = URL(fileURLWithPath: "/Volumes/Archive/Deck.pptx")

        do {
            _ = try await uploader.uploadFile(url, container: "mnemo", metadata: [:])
            XCTFail("Unknown binary formats must fail closed")
        } catch let error as LocalFirstCorpusUploadError {
            XCTAssertEqual(error, .unsupportedLocalType("pptx"))
        }
        let directPaths = await direct.paths
        XCTAssertTrue(directPaths.isEmpty)
        let calls = await creator.calls
        XCTAssertTrue(calls.isEmpty)
    }

    func testLocalExtractionWaitsForInteractiveQuery() async throws {
        let scheduler = WorkScheduler()
        let token = await scheduler.beginInteractive()
        let extraction = ExtractionCallRecorder()
        let uploader = LocalFirstCorpusUploader(
            directUploader: DirectUploadRecorder(),
            creator: CreatedDocumentRecorder(),
            scheduler: scheduler,
            extract: { _ in
                await extraction.record()
                return "local"
            }
        )
        let task = Task {
            try await uploader.uploadFile(
                URL(fileURLWithPath: "/Volumes/Archive/Plan.pdf"),
                container: "mnemo",
                metadata: [:]
            )
        }

        try await Task.sleep(for: .milliseconds(100))
        let callsWhileInteractive = await extraction.calls
        XCTAssertEqual(callsWhileInteractive, 0)

        await scheduler.endInteractive(token)
        _ = try await task.value
        let callsAfter = await extraction.calls
        XCTAssertEqual(callsAfter, 1)
    }
}
