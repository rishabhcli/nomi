import XCTest
@testable import MnemoOrchestrator

private struct StubSource: IngestSource {
    let kind: SourceKind
    func sync(limit: Int) async throws -> IngestReport {
        IngestReport(kind: kind, container: container,
                     uploaded: 0, unchanged: 0, deferred: 0, failures: 0)
    }
}

/// M13: the uniform ingest surface every source conforms to.
final class IngestSourceTests: XCTestCase {
    func testDefaultContainerComesFromKind() async throws {
        let source = StubSource(kind: .messages)
        XCTAssertEqual(source.container, "messages")

        let report = try await source.sync(limit: 5)
        XCTAssertEqual(report.kind, .messages)
        XCTAssertEqual(report.container, "messages")
    }
}
