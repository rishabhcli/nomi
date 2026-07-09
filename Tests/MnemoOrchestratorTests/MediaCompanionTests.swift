import XCTest
@testable import MnemoOrchestrator

private func doc(_ id: String, path: String?, status: String,
                 metadata: [String: String]? = nil) -> DocumentMeta {
    DocumentMeta(id: id, filepath: path, title: path, status: status,
                 containerTags: ["mnemo"], summary: nil, updatedAt: nil, metadata: metadata)
}

final class MediaCompanionPolicyTests: XCTestCase {
    func testMediaPathDetection() {
        XCTAssertTrue(MediaCompanion.isMediaPath("/x/scan.pdf"))
        XCTAssertTrue(MediaCompanion.isMediaPath("/x/photo.HEIC"))
        XCTAssertTrue(MediaCompanion.isMediaPath("/x/memo.m4a"))
        XCTAssertTrue(MediaCompanion.isMediaPath("/x/slides.docx"))
        XCTAssertFalse(MediaCompanion.isMediaPath("/x/notes.md"))
        XCTAssertFalse(MediaCompanion.isMediaPath("/x/plain.txt"))
    }

    func testCompanionsAreIdentifiedByMetadata() {
        let companion = doc("c1", path: nil, status: "done",
                            metadata: [MediaCompanion.companionOfKey: "d1"])
        XCTAssertEqual(MediaCompanion.companionOf(companion), "d1")
        XCTAssertNil(MediaCompanion.companionOf(doc("d1", path: "/a.pdf", status: "failed")))
    }

    func testNeedsExtractionOnlyForFailedMediaWithoutCompanion() {
        let failedPDF = doc("d1", path: "/scan.pdf", status: "failed")
        let failedMD = doc("d2", path: "/notes.md", status: "failed")
        let readyPDF = doc("d3", path: "/ok.pdf", status: "done")
        let failedWithCompanion = doc("d4", path: "/covered.m4a", status: "failed")
        let companion = doc("c4", path: nil, status: "done",
                            metadata: [MediaCompanion.companionOfKey: "d4"])
        let todo = MediaCompanion.needingExtraction(
            docs: [failedPDF, failedMD, readyPDF, failedWithCompanion, companion])
        XCTAssertEqual(todo.map(\.id), ["d1"], "only the uncovered failed media doc")
    }

    func testEffectiveStateMergesCompanionCoverage() {
        let failed = doc("d4", path: "/covered.m4a", status: "failed")
        let companion = doc("c4", path: nil, status: "done",
                            metadata: [MediaCompanion.companionOfKey: "d4"])
        let all = [failed, companion]
        XCTAssertEqual(MediaCompanion.effectiveState(of: failed, in: all), .ready,
                       "a covered media file is searchable → presents as ready")
        let uncovered = doc("d1", path: "/scan.pdf", status: "failed")
        XCTAssertEqual(MediaCompanion.effectiveState(of: uncovered, in: all + [uncovered]), .error)
    }

    func testMetadataDecodingKeepsStringValuesOnly() throws {
        let json = """
        {"memories":[{"id":"x","filepath":"/a.png","status":"failed",
          "metadata":{"source":"supermemoryfs","count":3,"flag":true}}],
         "pagination":{"currentPage":1,"totalPages":1}}
        """
        let page = try JSONDecoder().decode(EngineClient.DocumentListPage.self, from: Data(json.utf8))
        XCTAssertEqual(page.memories[0].metadata?.strings["source"], "supermemoryfs")
        XCTAssertNil(page.memories[0].metadata?.strings["count"], "non-string values dropped, not fatal")
    }
}

actor RecordingDocCreator: DocumentCreating {
    var created: [(content: String, customId: String, metadata: [String: String])] = []
    func createDocument(content: String, customId: String?, container: String?,
                        metadata: [String: String]) async throws -> String {
        created.append((content, customId ?? "", metadata))
        return "new-doc-\(created.count)"
    }
}

final class MediaIngestorTests: XCTestCase {
    func testExtractsAndPostsCompanionForFailedMedia() async throws {
        let creator = RecordingDocCreator()
        let ingestor = MediaIngestor(
            creator: creator,
            container: "mnemo",
            mountRoot: "/tmp/mnt",
            extract: { url in
                XCTAssertEqual(url.path, "/tmp/mnt/scan.pdf")
                return "EXTRACTED TEXT"
            })
        let n = await ingestor.sync(docs: [doc("d1", path: "/scan.pdf", status: "failed")])
        XCTAssertEqual(n, 1)
        let created = await creator.created
        XCTAssertEqual(created.count, 1)
        XCTAssertTrue(created[0].content.contains("EXTRACTED TEXT"))
        XCTAssertTrue(created[0].content.contains("scan.pdf"), "companion titled after the original")
        XCTAssertEqual(created[0].metadata[MediaCompanion.companionOfKey], "d1")
        XCTAssertEqual(created[0].metadata[MediaCompanion.originalPathKey], "/scan.pdf")
    }

    func testSkipsCoveredAndNonMediaAndUnextractable() async throws {
        let creator = RecordingDocCreator()
        let ingestor = MediaIngestor(
            creator: creator, container: "mnemo", mountRoot: "/tmp/mnt",
            extract: { _ in nil })   // extraction yields nothing
        let n = await ingestor.sync(docs: [
            doc("d1", path: "/scan.pdf", status: "failed"),      // unextractable → skipped
            doc("d2", path: "/notes.md", status: "failed"),      // not media
            doc("d3", path: "/ok.png", status: "done"),          // not failed
        ])
        XCTAssertEqual(n, 0)
        let created = await creator.created
        XCTAssertTrue(created.isEmpty)
    }
}
