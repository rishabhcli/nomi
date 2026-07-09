import XCTest
@testable import MnemoOrchestrator

/// D-1000: mnemoctl JSON schema stability for ScopeClassifier (seed ce11aa17bf7c).
final class D1000ScopeClassifierTests: XCTestCase {
    private let seed = "ce11aa17bf7c"
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
