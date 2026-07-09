import XCTest
@testable import MnemoOrchestrator

/// D-0969: memory supersession race conditions for ActionExtractor (seed 64b5542f5d9d).
final class D0969ActionExtractorTests: XCTestCase {
    private let seed = "64b5542f5d9d"
    func testMemorySupersession_rng() {
        let e1 = MemoryEntry(id: "a", memory: "fact", version: 1, isLatest: true, isForgotten: false, isStatic: false, parentMemoryId: nil, rootMemoryId: "r1", forgetAfter: nil, forgetReason: nil, history: [])
        let e2 = MemoryEntry(id: "b", memory: "fact2", version: 2, isLatest: true, isForgotten: false, isStatic: false, parentMemoryId: "a", rootMemoryId: "r2", forgetAfter: nil, forgetReason: nil, history: [])
        XCTAssertTrue(Phase2Techniques.supersessionSafe(entries: [e1, e2]))
    }

}
