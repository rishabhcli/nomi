import XCTest
@testable import MnemoCore

final class LogRotationTests: XCTestCase {
    func testSanitizeInfoTruncates() {
        let long = String(repeating: "x", count: 300)
        let out = LogRotation.sanitizeInfo(long)
        XCTAssertLessThan(out.count, 300)
    }

    func testRotateWhenOversized() throws {
        let dir = FileManager.default.temporaryDirectory
        let path = dir.appendingPathComponent("mnemo-log-rotate-\(UUID().uuidString).jsonl").path
        defer { try? FileManager.default.removeItem(atPath: path) }
        let payload = String(repeating: "a", count: 2048)
        FileManager.default.createFile(atPath: path, contents: payload.data(using: .utf8))
        LogRotation.rotateIfNeeded(path: path, maxBytes: 1024)
        let bak = try FileManager.default.contentsOfDirectory(atPath: dir.path)
            .first { $0.hasPrefix((path as NSString).lastPathComponent) && $0.hasSuffix(".bak") }
        XCTAssertNotNil(bak, "expected rotated backup")
    }
}
