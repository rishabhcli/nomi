import XCTest
@testable import MnemoOrchestrator

/// D-0780: mnemoctl JSON schema stability for OllamaClient (seed 6c70df026adf).
final class D0780OllamaClientTests: XCTestCase {
    private let seed = "6c70df026adf"
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
