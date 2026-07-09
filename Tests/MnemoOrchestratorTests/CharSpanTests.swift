import XCTest
@testable import MnemoOrchestrator

final class CharSpanTests: XCTestCase {
    func testExactSubstring() {
        let doc = "Alpha beta gamma delta."
        let r = CharSpan.resolve(chunk: "beta gamma", in: doc)!
        XCTAssertEqual(doc.substring(charRange: r), "beta gamma")
    }

    func testWhitespaceNormalizedChunkStillResolves() {
        // The engine collapses newlines/runs of spaces to single spaces when chunking.
        let doc = "# Build tooling notes\n\nMy favorite build tool is Bazel and I switched\nto it in March 2025."
        let chunk = "# Build tooling notes My favorite build tool is Bazel and I switched to it in March 2025."
        let r = CharSpan.resolve(chunk: chunk, in: doc)!
        XCTAssertEqual(r.lowerBound, 0)
        XCTAssertEqual(r.upperBound, doc.count)
        // Round-trip: the resolved slice normalizes to the chunk.
        let slice = doc.substring(charRange: r)
        XCTAssertEqual(slice.collapsedWhitespace, chunk.collapsedWhitespace)
    }

    func testInteriorNormalizedSpan() {
        let doc = "Header\n\nOne two   three four.\n\nFooter here"
        let chunk = "two three four."
        let r = CharSpan.resolve(chunk: chunk, in: doc)!
        let slice = doc.substring(charRange: r)
        XCTAssertEqual(slice.collapsedWhitespace, "two three four.")
    }

    func testAbsentChunkReturnsNil() {
        XCTAssertNil(CharSpan.resolve(chunk: "not present", in: "some other text"))
    }
}
