import XCTest
@testable import MnemoOrchestrator

/// D-0298: CommandParser TerminalState exhaustiveness (seed dc1fdee57359).
final class D0298CommandParserTests: XCTestCase {
    private let seed = "dc1fdee57359"

    func testIndexingTerminalState() {
        let ts = CommandParser.indexingTerminalState(path: "/docs/a.pdf")
        if case .indexing(let path) = ts { XCTAssertEqual(path, "/docs/a.pdf") }
        else { XCTFail("expected indexing terminal") }
    }

    func testLifecycleEventsNonEmpty() {
        XCTAssertFalse(CommandParser.lifecycleEvents(branch: .emptyEvidence).isEmpty)
    }

    func testProperty_terminalStateEquatable() {
        var rng = Phase2RNG(seed: seed)
        let paths = ["/a.pdf", "/b.md", "/c.txt"]
        for _ in 0..<4 {
            let p = paths[rng.nextInt(upperBound: paths.count)]
            XCTAssertEqual(CommandParser.indexingTerminalState(path: p), .indexing(path: p))
        }
    }
}
