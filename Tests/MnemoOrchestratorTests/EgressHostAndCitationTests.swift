import XCTest
@testable import MnemoOrchestrator

/// Regressions for two correctness bugs found during backend testing (2026-07-09):
/// the egress guard's spoofable "127." prefix check, and the citation stripper
/// deleting real parenthetical claim content.
final class EgressHostAndCitationTests: XCTestCase {
    func testGenuineLoopbackAccepted() {
        XCTAssertTrue(EgressGuard.isLoopbackHost("127.0.0.1"))
        XCTAssertTrue(EgressGuard.isLoopbackHost("127.5.6.7"))   // all of 127/8
        XCTAssertTrue(EgressGuard.isLoopbackHost("localhost"))
        XCTAssertTrue(EgressGuard.isLoopbackHost("::1"))
        XCTAssertTrue(EgressGuard.isLoopbackHost("[::1]"))
    }

    func testSpoofedLoopbackHostsAreRejected() {
        XCTAssertFalse(EgressGuard.isLoopbackHost("127.0.0.1.evil.com"))
        XCTAssertFalse(EgressGuard.isLoopbackHost("127.attacker.net"))
        XCTAssertFalse(EgressGuard.isLoopbackHost("127notanip.example.com"))
        XCTAssertFalse(EgressGuard.isLoopbackHost("128.0.0.1"))
        XCTAssertFalse(EgressGuard.isLoopbackHost("api.supermemory.ai"))
    }

    func testStripCitationsKeepsParentheticalClaimContent() {
        XCTAssertTrue(Verification.stripCitations("Revenue grew (to $2M in Q3) [Report].").contains("2M"))
        XCTAssertTrue(Verification.stripCitations("The reduction was (approximately 50%").contains("50"))
    }

    func testStripCitationsStillRemovesRealCitationMarkup() {
        XCTAssertFalse(Verification.stripCitations("Switched to Bazel [Build tooling notes].").contains("Build tooling"))
        XCTAssertFalse(Verification.stripCitations("The answer is 42 【fixture.md】.").contains("fixture.md"))
    }

    // P1: with a distractor date present, the numeric note must not force the
    // global earliest→latest span as the answer — it must list the dated facts
    // and tell the model to pick the correct endpoints.
    func testNumericNoteIsAdvisoryWithDistractorDate() {
        let ev = [
            Retrieved(memory: "The project kicked off on January 5, 2024.", similarity: 0.9,
                      source: SourceLocator(docId: "d1", path: "/a.md", title: "A")),
            Retrieved(memory: "Launch was targeted for June 1, 2024 but slipped to June 22, 2024.",
                      similarity: 0.9, source: SourceLocator(docId: "d2", path: "/b.md", title: "B")),
        ]
        let note = NumericReasoner.durationNote(in: ev) ?? ""
        XCTAssertFalse(note.contains("do not re-derive"),
                       "must not force a possibly-wrong global span")
        XCTAssertTrue(note.contains("Jun 1, 2024"),
                      "must list the individual dated facts so the model can pick endpoints")
        XCTAssertTrue(note.lowercased().contains("actual endpoints")
                        || note.lowercased().contains("correct start and end"))
    }
}
