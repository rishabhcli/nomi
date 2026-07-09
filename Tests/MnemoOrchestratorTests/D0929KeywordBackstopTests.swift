import XCTest
@testable import MnemoOrchestrator

/// D-0929: memory supersession race conditions for KeywordBackstop (seed 9d6e3b645b57).
final class D0929KeywordBackstopTests: XCTestCase {
    private let seed = "9d6e3b645b57"
    func testMemorySupersession_rng() {
        let e1 = MemoryEntry(id: "a", memory: "fact", version: 1, isLatest: true, isForgotten: false, isStatic: false, parentMemoryId: nil, rootMemoryId: "r1", forgetAfter: nil, forgetReason: nil, history: [])
        let e2 = MemoryEntry(id: "b", memory: "fact2", version: 2, isLatest: true, isForgotten: false, isStatic: false, parentMemoryId: "a", rootMemoryId: "r2", forgetAfter: nil, forgetReason: nil, history: [])
        XCTAssertTrue(Phase2Techniques.supersessionSafe(entries: [e1, e2]))
    }

}
