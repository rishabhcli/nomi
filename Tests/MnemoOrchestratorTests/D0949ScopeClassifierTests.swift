import XCTest
@testable import MnemoOrchestrator

/// D-0949: memory supersession race conditions for ScopeClassifier (seed 6eaf0d4aa254).
final class D0949ScopeClassifierTests: XCTestCase {
    private let seed = "6eaf0d4aa254"
    func testMemorySupersession_rng() {
        let e1 = MemoryEntry(id: "a", memory: "fact", version: 1, isLatest: true, isForgotten: false, isStatic: false, parentMemoryId: nil, rootMemoryId: "r1", forgetAfter: nil, forgetReason: nil, history: [])
        let e2 = MemoryEntry(id: "b", memory: "fact2", version: 2, isLatest: true, isForgotten: false, isStatic: false, parentMemoryId: "a", rootMemoryId: "r2", forgetAfter: nil, forgetReason: nil, history: [])
        XCTAssertTrue(Phase2Techniques.supersessionSafe(entries: [e1, e2]))
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
