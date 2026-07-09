import XCTest
@testable import MnemoOrchestrator

/// D-0625: cache poisoning resistance for ContextAssembler (seed 06cda44f0d81).
final class D0625ContextAssemblerTests: XCTestCase {
    private let seed = "06cda44f0d81"

    func testCache_resistsPoisonKeys() {
        XCTAssertFalse(ContextAssembler.resistsCachePoisoning("api.supermemory.ai"))
        XCTAssertTrue(ContextAssembler.resistsCachePoisoning("127.0.0.1"))
        XCTAssertFalse(ContextAssembler.resistsCachePoisoning("\0injected"))
    }

    func testCache_phase2PoisonRejected() {
        XCTAssertTrue(Phase2Techniques.cachePoisonKeyRejected("\0bad"))
    }

    func testCache_keySeparatesContainer() {
        let k1 = ContextAssembler.cacheKey(query: "q", container: "a", extra: "1")
        let k2 = ContextAssembler.cacheKey(query: "q", container: "b", extra: "1")
        XCTAssertNotEqual(k1, k2)
    }
}
