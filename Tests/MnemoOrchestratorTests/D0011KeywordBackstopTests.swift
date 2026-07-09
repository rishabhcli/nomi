import XCTest
@testable import MnemoOrchestrator

/// D-0011: KeywordBackstop agentic grep deadlock prevention (seed efe7789f5606).
final class D0011KeywordBackstopTests: XCTestCase {
    private let seed = "efe7789f5606"

    func testMaxFilesScannedCap() throws {
        let dir = FileManager.default.temporaryDirectory.appending(path: "kb-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        for i in 0..<40 {
            try "term\(i) content".write(to: dir.appending(path: "f\(i).md"), atomically: true, encoding: .utf8)
        }
        let hits = KeywordBackstop.grep(term: "term25", root: dir.path, maxMatches: 3)
        XCTAssertFalse(hits.isEmpty)
    }

    func testMaxRescueTermsLimitsSearch() {
        let q = "alpha beta gamma delta epsilon zeta eta theta iota kappa"
        let terms = KeywordBackstop.salientTerms(q)
        XCTAssertGreaterThan(terms.count, KeywordBackstop.maxRescueTerms)
        let (_, note) = KeywordBackstop.rescue(query: q, evidence: [], mountRoot: "/nonexistent")
        XCTAssertNil(note)
    }

    func testUncoveredIgnoresChatRecall() {
        let ev = [Retrieved(memory: "chrome browser", similarity: 0.5,
                            source: SourceLocator(docId: "", path: "", title: QueryService.chatRecallTitle))]
        let missing = KeywordBackstop.uncovered(terms: ["chrome"], in: ev)
        XCTAssertEqual(missing, ["chrome"])
    }

    func testProperty_salientTermsDeterministic() {
        var rng = Phase2RNG(seed: seed)
        for _ in 0..<10 {
            let q = rng.randomQuery(length: 4)
            let a = KeywordBackstop.salientTerms(q)
            let b = KeywordBackstop.salientTerms(q)
            XCTAssertEqual(a, b)
        }
    }
}
