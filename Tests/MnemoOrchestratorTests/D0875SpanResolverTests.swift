import XCTest
@testable import MnemoOrchestrator

/// D-0875: egress guard host parsing for SpanResolver (seed f462ea05f4e5).
final class D0875SpanResolverTests: XCTestCase {
    private let seed = "f462ea05f4e5"
    func testEgressHostParsing_rng() {
        XCTAssertTrue(EgressGuard.isLoopbackHost("127.0.0.1"))
        XCTAssertFalse(EgressGuard.isLoopbackHost("127.0.0.1.evil.com"))
        XCTAssertTrue(Phase2Techniques.parseHostForEgress("localhost"))
    }

}
