import XCTest
@testable import MnemoOrchestrator

/// M13: the shared incremental checkpoint every source uses to skip unchanged
/// items and resume after interruption.
final class SourceCheckpointTests: XCTestCase {
    private func tempURL() -> URL {
        FileManager.default.temporaryDirectory
            .appending(path: "source-checkpoint-\(UUID().uuidString)/cp.json")
    }

    func testRecordsAndDetectsChangeByFingerprint() async throws {
        let url = tempURL()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let cp = SourceCheckpoint(url: url)

        let unchangedBefore = await cp.isUnchanged(key: "/a.txt", fingerprint: "fp1")
        XCTAssertFalse(unchangedBefore, "an unrecorded item is not unchanged")

        try await cp.record(key: "/a.txt", fingerprint: "fp1", documentId: "doc1")

        let same = await cp.isUnchanged(key: "/a.txt", fingerprint: "fp1")
        let changed = await cp.isUnchanged(key: "/a.txt", fingerprint: "fp2")
        let docId = await cp.documentId(for: "/a.txt")
        XCTAssertTrue(same)
        XCTAssertFalse(changed, "a new fingerprint means the item changed")
        XCTAssertEqual(docId, "doc1")
    }

    func testPersistsAcrossInstances() async throws {
        let url = tempURL()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let first = SourceCheckpoint(url: url)
        try await first.record(key: "/b.txt", fingerprint: "fpB", documentId: "docB")

        let reloaded = SourceCheckpoint(url: url)
        let unchanged = await reloaded.isUnchanged(key: "/b.txt", fingerprint: "fpB")
        let docId = await reloaded.documentId(for: "/b.txt")
        XCTAssertTrue(unchanged, "checkpoint must survive a reload")
        XCTAssertEqual(docId, "docB")
    }

    func testForgetDropsAnItem() async throws {
        let url = tempURL()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let cp = SourceCheckpoint(url: url)
        try await cp.record(key: "/c.txt", fingerprint: "fpC", documentId: "docC")
        try await cp.forget(key: "/c.txt")
        let unchanged = await cp.isUnchanged(key: "/c.txt", fingerprint: "fpC")
        XCTAssertFalse(unchanged, "a forgotten item is re-ingested on the next pass")
    }
}
