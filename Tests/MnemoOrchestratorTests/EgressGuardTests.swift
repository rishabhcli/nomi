import XCTest
@testable import MnemoOrchestrator

final class LoopbackClassifyTests: XCTestCase {
    func testLoopbackHostsAreAllowed() {
        XCTAssertTrue(EgressGuard.isLoopbackHost("127.0.0.1"))
        XCTAssertTrue(EgressGuard.isLoopbackHost("localhost"))
        XCTAssertTrue(EgressGuard.isLoopbackHost("::1"))
        XCTAssertTrue(EgressGuard.isLoopbackHost("127.0.0.53"))
    }
    func testNonLoopbackHostsAreEgress() {
        XCTAssertFalse(EgressGuard.isLoopbackHost("api.supermemory.ai"))
        XCTAssertFalse(EgressGuard.isLoopbackHost("10.0.0.16"))
        XCTAssertFalse(EgressGuard.isLoopbackHost("8.8.8.8"))
        XCTAssertFalse(EgressGuard.isLoopbackHost("generativelanguage.googleapis.com"))
    }
}

final class EgressGuardTests: XCTestCase {
    func testWindowCountsAndCleanliness() async {
        let guard0 = EgressGuard()
        let window = await guard0.beginQueryWindow()
        var clean = await guard0.isClean()
        XCTAssertTrue(clean)
        await guard0.recordAttempt(host: "api.supermemory.ai")   // simulated egress attempt
        let n = await guard0.outboundNonLoopbackAttempts
        clean = await guard0.isClean()
        XCTAssertEqual(n, 1)
        XCTAssertFalse(clean)
        await guard0.endWindow(window)
    }

    func testLoopbackAttemptsDoNotCount() async {
        let g = EgressGuard()
        _ = await g.beginQueryWindow()
        await g.recordAttempt(host: "127.0.0.1")
        await g.recordAttempt(host: "localhost")
        let n = await g.outboundNonLoopbackAttempts
        XCTAssertEqual(n, 0)
        let clean = await g.isClean()
        XCTAssertTrue(clean)
    }
}

/// The in-process interposer: our URLSession clients route through it; a
/// non-loopback request is blocked and counted (AT-M10.3).
final class LoopbackGuardURLProtocolTests: XCTestCase {
    override func tearDown() {
        LoopbackGuardURLProtocol.reset()
        super.tearDown()
    }

    func testBlocksAndCountsNonLoopbackRequest() async {
        LoopbackGuardURLProtocol.reset()
        let cfg = URLSessionConfiguration.ephemeral
        cfg.protocolClasses = [LoopbackGuardURLProtocol.self]
        let session = URLSession(configuration: cfg)
        do {
            _ = try await session.data(from: URL(string: "https://api.supermemory.ai/v4/search")!)
            XCTFail("non-loopback request must be blocked")
        } catch {
            XCTAssertEqual(LoopbackGuardURLProtocol.blockedCount, 1)
        }
    }

    func testAllowsLoopbackRequest() {
        // canInit must be false for loopback so the normal loader handles it.
        let loopback = URLRequest(url: URL(string: "http://127.0.0.1:6767/v4/search")!)
        let external = URLRequest(url: URL(string: "https://api.supermemory.ai")!)
        XCTAssertFalse(LoopbackGuardURLProtocol.canInit(with: loopback))
        XCTAssertTrue(LoopbackGuardURLProtocol.canInit(with: external))
    }
}

final class PrivacyIndicatorTests: XCTestCase {
    func testIndicatorReflectsMeasuredState() async {
        let g = EgressGuard()
        _ = await g.beginQueryWindow()
        var indicator = await PrivacyIndicator.from(g)
        XCTAssertEqual(indicator, .clean)
        await g.recordAttempt(host: "8.8.8.8")
        indicator = await PrivacyIndicator.from(g)
        XCTAssertEqual(indicator, .egressDetected(count: 1))
    }
}
