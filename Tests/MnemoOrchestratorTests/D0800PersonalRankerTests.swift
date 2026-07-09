import XCTest
@testable import MnemoOrchestrator

/// D-0800: mnemoctl JSON schema stability for PersonalRanker (seed 9af8b82c949f).
final class D0800PersonalRankerTests: XCTestCase {
    private let seed = "9af8b82c949f"
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
