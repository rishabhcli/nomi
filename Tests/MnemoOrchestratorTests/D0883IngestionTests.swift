import XCTest
@testable import MnemoOrchestrator

/// D-0883: char-span fuzzing for Ingestion (seed dc531e0f3290).
final class D0883IngestionTests: XCTestCase {
    private let seed = "dc531e0f3290"
    func testCharSpanFuzz_rng() {
        let doc = "alpha beta gamma delta"
        XCTAssertTrue(Phase2Techniques.charSpanFuzzSafe(doc: doc, chunk: "beta gamma"))
        XCTAssertNotNil(CharSpan.resolve(chunk: "beta gamma", in: doc))
    }

}
