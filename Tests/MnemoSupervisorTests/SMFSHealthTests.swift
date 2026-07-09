import XCTest
@testable import MnemoSupervisor

final class SMFSHealthTests: XCTestCase {
    func testLoopbackMountHealthy() {
        let tmp = FileManager.default.temporaryDirectory.path
        let s = SMFSHealth.check(mountPoint: tmp, boundAddress: "127.0.0.1:11111")
        XCTAssertTrue(s.mounted)
        XCTAssertTrue(s.loopback)
        XCTAssertTrue(s.healthy)
    }

    func testNonLoopbackBoundUnhealthy() {
        let s = SMFSHealth.check(mountPoint: "/tmp", boundAddress: "0.0.0.0:11111")
        XCTAssertFalse(s.healthy)
    }
}
