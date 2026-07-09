import XCTest
@testable import MnemoOrchestrator

/// D-0176: LLMSynthesizer subprocess stderr backpressure (seed a577e52a196d).
final class D0176LLMSynthesizerTests: XCTestCase {
    private let seed = "a577e52a196d"

    func testDrainsSubprocessStderr() {
        XCTAssertTrue(LLMSynthesizer.drainsSubprocessStderr())
    }
}
