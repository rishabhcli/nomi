import XCTest
@testable import MnemoOrchestrator

/// D-0007: CitationVerifier router escalation boundaries (seed 0f386ab3d7a5).
final class D0007CitationVerifierTests: XCTestCase {
    private let seed = "0f386ab3d7a5"

    let evidence = [
        Retrieved(memory: "Bazel is the build tool.", similarity: 0.9,
                  source: SourceLocator(docId: "d1", path: "/a.md", title: "A")),
    ]

    func testPartialFailureTriggersEscalation() async {
        let backend = StubVerifierBackend(
            similarity: { premise, claim in claim.contains("Bazel") ? 0.9 : 0.1 },
            entails: { _, claim in claim.contains("Bazel") })
        let verdicts = await CitationVerifier(backend: backend, simThreshold: 0.5)
            .verify(answer: "Bazel is used. Cats are nice.", evidence: evidence)
        XCTAssertTrue(CitationVerifier.needsRouterEscalation(verdicts))
        let events = CitationVerifier.routerEscalationEvents(verdicts)
        XCTAssertFalse(events.isEmpty)
        var state = NotchState(phase: .input, query: "q", answer: "", sources: [])
        for e in events { state = NotchReducer.apply(e, to: state) }
        XCTAssertFalse(state.reasoning.isEmpty)
    }

    func testAllUnsupportedDoesNotEscalate() async {
        let backend = StubVerifierBackend(similarity: { _, _ in 0.1 }, entails: { _, _ in false })
        let verdicts = await CitationVerifier(backend: backend).verify(answer: "A. B.", evidence: evidence)
        XCTAssertTrue(CitationVerifier.allUnsupported(verdicts))
        XCTAssertFalse(CitationVerifier.needsRouterEscalation(verdicts))
    }

    func testTrivialFragmentSkippedNotEscalated() async {
        let backend = StubVerifierBackend(similarity: { _, _ in 0.1 }, entails: { _, _ in false })
        let verdicts = await CitationVerifier(backend: backend).verify(answer: "Ok.", evidence: evidence)
        XCTAssertFalse(CitationVerifier.needsRouterEscalation(verdicts))
    }

    func testProperty_escalationOnlyOnPartialGrounding() async {
        var rng = Phase2RNG(seed: seed)
        for _ in 0..<6 {
            let supported = rng.nextInt(upperBound: 2) == 0
            let backend = StubVerifierBackend(
                similarity: { _, _ in supported ? 0.9 : 0.1 },
                entails: { _, _ in supported })
            let verdicts = await CitationVerifier(backend: backend)
                .verify(answer: "Fact one. Fact two.", evidence: evidence)
            if supported {
                XCTAssertFalse(CitationVerifier.needsRouterEscalation(verdicts))
            }
        }
    }
}
