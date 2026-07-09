import XCTest
@testable import MnemoOrchestrator

/// D-0880: mnemoctl JSON schema stability for ContextAssembler (seed 4701db9e4207).
final class D0880ContextAssemblerTests: XCTestCase {
    private let seed = "4701db9e4207"
    func testMnemoctlJSONSchema_rng() throws {
        var rng = Phase2RNG(seed: seed)
        let q = rng.randomQuery(length: 3)
        let c = ScopeClassifier.classify(q)
        XCTAssertEqual(c.schemaVersion, ScopeClassification.schemaVersion)
        let data = try c.jsonData()
        let json = String(data: data, encoding: .utf8) ?? ""
        XCTAssertTrue(json.contains("schemaVersion"))
        XCTAssertTrue(json.contains("isCorpusQuestion"))
    }

    func testClassifyChitChat() {
        let c = ScopeClassifier.classify("hello")
        XCTAssertFalse(c.isCorpusQuestion)
        XCTAssertNotNil(c.reply)
    }
    func testClassifyCorpus() {
        let c = ScopeClassifier.classify("what is in my notes about bazel?")
        XCTAssertTrue(c.isCorpusQuestion)
        XCTAssertNil(c.reply)
    }
}
