import XCTest
@testable import MnemoSupervisor

final class HealthProbeTests: XCTestCase {
    func testUpWhenResponds() async {
        StubURLProtocol.handler = { _ in (HTTPURLResponse(url: URL(string: "http://127.0.0.1:6767")!, statusCode: 200, httpVersion: nil, headerFields: nil)!, Data()) }
        let cfg = URLSessionConfiguration.ephemeral
        cfg.protocolClasses = [StubURLProtocol.self]
        let probe = HTTPHealthProbe(session: URLSession(configuration: cfg))
        let up = await probe.isUp(URL(string: "http://127.0.0.1:6767/health")!)
        XCTAssertTrue(up)
    }
    func testDownWhenError() async {
        StubURLProtocol.handler = { _ in throw URLError(.cannotConnectToHost) }
        let cfg = URLSessionConfiguration.ephemeral
        cfg.protocolClasses = [StubURLProtocol.self]
        let probe = HTTPHealthProbe(session: URLSession(configuration: cfg))
        let up = await probe.isUp(URL(string: "http://127.0.0.1:6767/health")!)
        XCTAssertFalse(up)
    }
}

final class StubURLProtocol: URLProtocol {
    nonisolated(unsafe) static var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for r: URLRequest) -> URLRequest { r }
    override func startLoading() {
        do {
            let (resp, data) = try Self.handler!(request)
            client?.urlProtocol(self, didReceive: resp, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch { client?.urlProtocol(self, didFailWithError: error) }
    }
    override func stopLoading() {}
}
