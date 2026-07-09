import XCTest
@testable import MnemoOrchestrator

/// D-0149: Digest memory supersession race conditions (seed 6321966c17f0).
final class D0149DigestTests: XCTestCase {
    private let seed = "6321966c17f0"

    func testSupersessionRaceSafe() {
        let k1 = Digest.supersessionKey(id: "a", version: 1)
        let k2 = Digest.supersessionKey(id: "a", version: 2)
        XCTAssertNotEqual(k1, k2)
        XCTAssertTrue(Digest.supersessionRaceSafe())
    }
}
