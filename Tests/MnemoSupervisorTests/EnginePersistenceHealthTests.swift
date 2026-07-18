import XCTest
@testable import MnemoSupervisor

final class EnginePersistenceHealthTests: XCTestCase {
    func testLatestSnapshotFailureIsUnhealthy() {
        let log = """
        [storage] Snapshot: 100 KB in 20ms
        [storage] Snapshot failed: RangeError: Out of memory
        """

        XCTAssertEqual(
            EnginePersistenceHealth.failureReason(in: log),
            "engine persistence snapshot failed"
        )
    }

    func testLaterSuccessfulSnapshotClearsFailure() {
        let log = """
        [storage] Snapshot failed: RangeError: Out of memory
        [storage] Snapshot: 100 KB in 20ms
        """

        XCTAssertNil(EnginePersistenceHealth.failureReason(in: log))
    }

    func testUnrelatedErrorsDoNotImplyPersistenceFailure() {
        XCTAssertNil(EnginePersistenceHealth.failureReason(in: "request failed"))
    }

    func testMinifiedSourceMarkersInsideStackTraceAreIgnored() {
        let log = #"2844 | source="[storage] Snapshot:"; error="[storage] Snapshot failed""#

        XCTAssertNil(EnginePersistenceHealth.failureReason(in: log))
    }

    func testTailDecodeSurvivesStartingInsideMultibyteScalar() throws {
        let directory = FileManager.default.temporaryDirectory
        let logURL = directory.appendingPathComponent("mnemo-engine-log-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: logURL) }
        let contents = Data("x€\n[storage] Snapshot failed: RangeError\n".utf8)
        try contents.write(to: logURL)

        XCTAssertEqual(
            EnginePersistenceHealth.failureReason(
                at: logURL.path,
                maximumBytes: UInt64(contents.count - 2)
            ),
            "engine persistence snapshot failed"
        )
    }

    func testDeveloperObservatoryIncludesPersistenceHealth() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let source = try String(
            contentsOf: root.appendingPathComponent("Sources/MnemoApp/DevTools.swift"),
            encoding: .utf8
        )

        XCTAssertTrue(source.contains("import MnemoSupervisor"))
        XCTAssertTrue(source.contains("EnginePersistenceHealth.failureReason"))
        XCTAssertTrue(source.contains("additionalUnhealthyReasons:"))
    }
}
