import Darwin
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

    func testUnrecoveredFailureBeforeReadWindowRemainsUnhealthy() throws {
        let directory = FileManager.default.temporaryDirectory
        let logURL = directory.appendingPathComponent("mnemo-engine-log-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: logURL) }
        let unrelatedGrowth = String(repeating: "request completed\n", count: 32)
        try Data("[storage] Snapshot failed: RangeError\n\(unrelatedGrowth)".utf8)
            .write(to: logURL)

        XCTAssertEqual(
            EnginePersistenceHealth.failureReason(at: logURL.path, maximumBytes: 32),
            "engine persistence snapshot failed"
        )
    }

    func testRecoveryBeforeReadWindowClearsEarlierFailure() throws {
        let directory = FileManager.default.temporaryDirectory
        let logURL = directory.appendingPathComponent("mnemo-engine-log-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: logURL) }
        let unrelatedGrowth = String(repeating: "request completed\n", count: 32)
        let contents = """
            [storage] Snapshot failed: RangeError
            [storage] Snapshot: 100 KB in 20ms
            \(unrelatedGrowth)
            """
        try Data(contents.utf8).write(to: logURL)

        XCTAssertNil(
            EnginePersistenceHealth.failureReason(at: logURL.path, maximumBytes: 32)
        )
    }

    func testFailureMarkerSplitAcrossReadWindowsIsFound() throws {
        let directory = FileManager.default.temporaryDirectory
        let logURL = directory.appendingPathComponent("mnemo-engine-log-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: logURL) }
        let prefix = "ignore\n"
        let failure = "[storage] Snapshot failed: RangeError\n"
        let suffix = String(repeating: "x", count: 64 - prefix.utf8.count - failure.utf8.count)
        try Data("\(prefix)\(failure)\(suffix)".utf8).write(to: logURL)

        XCTAssertEqual(
            EnginePersistenceHealth.failureReason(at: logURL.path, maximumBytes: 16),
            "engine persistence snapshot failed"
        )
    }

    func testMarkerFreeScanKeepsResidentMemoryBoundedAcrossManyWindows() throws {
        let directory = FileManager.default.temporaryDirectory
        let logURL = directory.appendingPathComponent("mnemo-engine-log-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: logURL) }
        XCTAssertTrue(FileManager.default.createFile(atPath: logURL.path, contents: nil))
        let handle = try FileHandle(forWritingTo: logURL)
        try handle.truncate(atOffset: 64 * 1024 * 1024)
        try handle.close()

        let residentBefore = try residentBytes()
        XCTAssertNil(
            EnginePersistenceHealth.failureReason(at: logURL.path, maximumBytes: 512 * 1024)
        )
        let residentAfter = try residentBytes()
        let residentGrowth = residentAfter > residentBefore ? residentAfter - residentBefore : 0

        XCTAssertLessThan(
            residentGrowth,
            32 * 1024 * 1024,
            "scanning chunked log input must not retain every read window"
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

    private func residentBytes() throws -> UInt64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(
            MemoryLayout<mach_task_basic_info>.size / MemoryLayout<natural_t>.size
        )
        let result = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(
                    mach_task_self_,
                    task_flavor_t(MACH_TASK_BASIC_INFO),
                    $0,
                    &count
                )
            }
        }
        guard result == KERN_SUCCESS else {
            throw NSError(domain: NSMachErrorDomain, code: Int(result))
        }
        return info.resident_size
    }
}
