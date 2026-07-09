import XCTest
@testable import MnemoOrchestrator

/// D-0229: Profile memory supersession race conditions (seed 99f5364b9924).
final class D0229ProfileTests: XCTestCase {
    private let seed = "99f5364b9924"

    func testSupersessionRaceSafe() {
        let k1 = Profile.supersessionKey(id: "a", version: 1)
        let k2 = Profile.supersessionKey(id: "a", version: 2)
        XCTAssertNotEqual(k1, k2)
        XCTAssertTrue(Profile.supersessionRaceSafe())
    }
}
