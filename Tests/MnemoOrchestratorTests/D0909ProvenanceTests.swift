import XCTest
@testable import MnemoOrchestrator

/// D-0909: memory supersession race conditions for Provenance (seed 53dac8cd0349).
final class D0909ProvenanceTests: XCTestCase {
    private let seed = "53dac8cd0349"
    func testMemorySupersession_rng() {
        let e1 = MemoryEntry(id: "a", memory: "fact", version: 1, isLatest: true, isForgotten: false, isStatic: false, parentMemoryId: nil, rootMemoryId: "r1", forgetAfter: nil, forgetReason: nil, history: [])
        let e2 = MemoryEntry(id: "b", memory: "fact2", version: 2, isLatest: true, isForgotten: false, isStatic: false, parentMemoryId: "a", rootMemoryId: "r2", forgetAfter: nil, forgetReason: nil, history: [])
        XCTAssertTrue(Phase2Techniques.supersessionSafe(entries: [e1, e2]))
    }

}
