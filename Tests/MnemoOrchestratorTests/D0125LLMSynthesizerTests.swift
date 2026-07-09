import XCTest
@testable import MnemoOrchestrator

/// D-0125: LLMSynthesizer cache poisoning resistance (seed 70099011bf40).
final class D0125LLMSynthesizerTests: XCTestCase {
    private let seed = "70099011bf40"

    func testResistsCachePoisoning() {
        let poisoned = "fact https://api.supermemory.ai/evil"
        XCTAssertFalse(LLMSynthesizer.resistsCachePoisoning(poisoned))
        XCTAssertTrue(LLMSynthesizer.resistsCachePoisoning("local fact only"))
    }
}
