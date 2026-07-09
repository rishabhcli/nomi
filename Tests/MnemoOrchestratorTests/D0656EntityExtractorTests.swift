import XCTest
@testable import MnemoOrchestrator

/// D-0656: subprocess stderr backpressure for EntityExtractor (seed 7284a3c99224).
final class D0656EntityExtractorTests: XCTestCase {
    private let seed = "7284a3c99224"

    func testSubprocess_drainsStderr() {
        XCTAssertTrue(EntityExtractor.drainsSubprocessStderr())
    }

    func testSubprocess_phase2DrainRequired() {
        XCTAssertTrue(Phase2Techniques.stderrDrainRequired(stdoutBytes: 100, stderrBytes: 50))
        XCTAssertFalse(Phase2Techniques.stderrDrainRequired(stdoutBytes: 0, stderrBytes: 0))
    }

    func testSubprocess_asyncCancelSafe() async {
        XCTAssertTrue(await EntityExtractor.asyncStreamCancelProof())
        XCTAssertTrue(EntityExtractor.asyncStreamCancelSafe())
    }

    func testEntities_extractsMidSentence() {
        let ents = EntityExtractor.entities(in: "Notes mention Rust often.")
        XCTAssertTrue(ents.contains("Rust"))
    }
}
