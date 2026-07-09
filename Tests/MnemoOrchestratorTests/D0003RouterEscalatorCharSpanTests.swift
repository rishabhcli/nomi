import XCTest
@testable import MnemoOrchestrator

/// D-0003: RouterEscalator char-span fuzzing (seed 88219ab5fa15).
final class D0003RouterEscalatorCharSpanTests: XCTestCase {
    private let seed = "88219ab5fa15"

    struct StubGenerator: Generating {
        let response: String
        func stream(system: String, prompt: String) -> AsyncThrowingStream<String, Error> {
            AsyncThrowingStream { c in
                c.yield(response)
                c.finish()
            }
        }
    }

    func testParseExtractsIntentFromNoisyModelOutput() {
        XCTAssertEqual(LLMRouterEscalator.parse("thinking… lookup because single fact"), .lookup)
        XCTAssertEqual(LLMRouterEscalator.parse("multihop across documents"), .multihop)
        XCTAssertEqual(LLMRouterEscalator.parse("garbage"), .synthesis)
    }

    func testClassifyUsesParsedIntentNotAlwaysSynthesis() async {
        let esc = LLMRouterEscalator(generator: StubGenerator(response: "lookup"))
        let intent = await esc.classify("what is bazel?")
        XCTAssertEqual(intent, .lookup)
    }

    func testCharSpanFuzzWithRouterEscalatorPrompts() {
        var rng = Phase2RNG(seed: seed)
        let content = "alpha beta gamma delta epsilon zeta"
        for _ in 0..<30 {
            let start = rng.nextInt(upperBound: content.count)
            let end = min(content.count, start + 1 + rng.nextInt(upperBound: 8))
            let slice = String(content[content.index(content.startIndex, offsetBy: start)..<content.index(content.startIndex, offsetBy: end)])
            let span = CharSpan.resolve(chunk: slice, in: content)
            if !slice.trimmingCharacters(in: .whitespaces).isEmpty {
                XCTAssertNotNil(span, "non-empty slice should resolve: \(slice)")
            }
        }
    }

    func testEmptyEvidenceEventsRenderable() {
        let events = LLMRouterEscalator.emptyEvidenceEvents()
        var state = NotchState(phase: .input, query: "q", answer: "", sources: [])
        for e in events { state = NotchReducer.apply(e, to: state) }
        XCTAssertFalse(state.reasoning.isEmpty)
    }
}
