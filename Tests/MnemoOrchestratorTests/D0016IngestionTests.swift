import XCTest
@testable import MnemoOrchestrator

/// D-0016: Ingestion subprocess stderr backpressure (seed 8802ac5c49b0).
final class D0016IngestionTests: XCTestCase {
    private let seed = "8802ac5c49b0"

    func testSubprocessCaptureDrainsStderr() throws {
        let script = FileManager.default.temporaryDirectory.appending(path: "mnemo-stderr-\(UUID().uuidString).sh")
        defer { try? FileManager.default.removeItem(at: script) }
        let body = "#!/bin/sh\necho out\ni=0; while [ $i -lt 100 ]; do echo err$i >&2; i=$((i+1)); done\n"
        try body.write(to: script, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: script.path)
        let out = try IngestionSubprocess.capture("/bin/sh", [script.path])
        XCTAssertTrue(out.contains("out"))
    }

    func testRefreshReturnsFalseOnEngineFailure() async {
        struct FailingDocs: DocumentIndexing {
            func documentsList(container: String?) async throws -> [DocumentMeta] {
                throw EngineError.httpStatus(503)
            }
        }
        let index = IngestIndex(docs: FailingDocs(), container: "mnemo")
        let ok = await index.refresh()
        XCTAssertFalse(ok)
    }

    func testRefreshReturnsTrueOnSuccess() async {
        struct OneDoc: DocumentIndexing {
            func documentsList(container: String?) async throws -> [DocumentMeta] {
                [DocumentMeta(id: "d1", filepath: "/a.md", title: "a", status: "done",
                              containerTags: ["mnemo"], summary: nil, updatedAt: nil)]
            }
        }
        let index = IngestIndex(docs: OneDoc(), container: "mnemo")
        let ok = await index.refresh()
        XCTAssertTrue(ok)
        XCTAssertEqual(await index.documentCount, 1)
    }

    func testProperty_indexingTerminalStateRenderable() {
        var rng = Phase2RNG(seed: seed)
        for _ in 0..<6 {
            let path = "/docs/file\(rng.nextInt(upperBound: 100)).pdf"
            let t = ItemState.indexingTerminalState(path: path)
            XCTAssertFalse(NotchReducer.message(for: t).isEmpty)
        }
    }
}
