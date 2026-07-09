import XCTest
@testable import MnemoOrchestrator

final class ItemStateTests: XCTestCase {
    func testEngineStatusMapping() {
        XCTAssertEqual(ItemState(engineStatus: "queued"), .queued)
        XCTAssertEqual(ItemState(engineStatus: "unknown"), .queued)
        XCTAssertEqual(ItemState(engineStatus: "extracting"), .processing)
        XCTAssertEqual(ItemState(engineStatus: "chunking"), .processing)
        XCTAssertEqual(ItemState(engineStatus: "embedding"), .processing)
        XCTAssertEqual(ItemState(engineStatus: "indexing"), .processing)
        XCTAssertEqual(ItemState(engineStatus: "done"), .ready)
        XCTAssertEqual(ItemState(engineStatus: "failed"), .error)
    }

    func testTerminalFlags() {
        XCTAssertTrue(ItemState.ready.isTerminal)
        XCTAssertTrue(ItemState.error.isTerminal)
        XCTAssertFalse(ItemState.queued.isTerminal)
        XCTAssertFalse(ItemState.processing.isTerminal)
    }
}

final class DocumentsDecodeTests: XCTestCase {
    // Captured from the live engine: POST /v3/documents/list
    static let listJSON = """
    {"memories":[{"connectionId":null,"containerTags":["mnemo"],"createdAt":"2026-07-08T17:22:10.125Z",
      "customId":null,"filepath":"/fixture.md","id":"m6eJLdtZcFFQ7B4dVBePXg",
      "metadata":{"lastEditedBy":"vk","source":"supermemoryfs"},"status":"done","summary":null,
      "title":"# Build tooling notes",
      "type":"text","updatedAt":"2026-07-08T17:23:26.452Z","url":null}],
     "pagination":{"currentPage":1,"limit":10,"totalItems":1,"totalPages":1}}
    """

    func testDecodesDocumentList() throws {
        let page = try JSONDecoder().decode(EngineClient.DocumentListPage.self, from: Data(Self.listJSON.utf8))
        XCTAssertEqual(page.memories.count, 1)
        let d = page.memories[0]
        XCTAssertEqual(d.id, "m6eJLdtZcFFQ7B4dVBePXg")
        XCTAssertEqual(d.filepath, "/fixture.md")
        XCTAssertEqual(d.status, "done")
        XCTAssertEqual(d.state, .ready)
        XCTAssertEqual(page.pagination.totalPages, 1)
    }
}
