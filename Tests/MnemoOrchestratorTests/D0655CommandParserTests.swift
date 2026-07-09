import XCTest
@testable import MnemoOrchestrator

/// D-0655: egress guard host parsing for CommandParser (seed 6fd84f449ce2).
final class D0655CommandParserTests: XCTestCase {
    private let seed = "6fd84f449ce2"

    func testEgress_hostParsingSafe() {
        XCTAssertTrue(CommandParser.egressHostParsingSafe())
    }

    func testEgress_loopbackOnly() {
        XCTAssertTrue(EgressGuard.isLoopbackHost("127.0.0.1"))
        XCTAssertFalse(EgressGuard.isLoopbackHost("127.0.0.1.evil.com"))
    }

    func testEgress_phase2Parse() {
        XCTAssertTrue(Phase2Techniques.parseHostForEgress("localhost"))
        XCTAssertFalse(Phase2Techniques.parseHostForEgress("example.com"))
    }

    func testParse_slashCommands() {
        XCTAssertEqual(CommandParser.parse("/help"), .command(.help))
        XCTAssertEqual(CommandParser.parse("plain query"), .query("plain query"))
    }
}
