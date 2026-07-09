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

final class A228RegressionTests: XCTestCase {
    func testA228_forgottenFactExcludedAfterForget() {
        let forgotten = MemoryEntry(id: "m228", memory: "Forgotten fact 228.", version: 1,
                                    isLatest: true, isForgotten: true, isStatic: false,
                                    parentMemoryId: nil, rootMemoryId: "m228",
                                    forgetAfter: nil, forgetReason: "user retraction", history: [])
        let active = MemoryEntry(id: "m228b", memory: "Active fact 228.", version: 1,
                                 isLatest: true, isForgotten: false, isStatic: false,
                                 parentMemoryId: nil, rootMemoryId: "m228b",
                                 forgetAfter: nil, forgetReason: nil, history: [])
        let filtered = MemoryFactFilter.filterActive([forgotten, active])
        XCTAssertEqual(filtered.map(\.id), ["m228b"],
                       "re-asked queries must not surface facts retracted via /forget")
    }

    func testA228_ttlExpiredExcluded() {
        let past = ISO8601DateFormatter().string(from: Date().addingTimeInterval(-3600))
        let expired = MemoryEntry(id: "e228", memory: "TTL fact 228.", version: 1,
                                  isLatest: true, isForgotten: false, isStatic: false,
                                  parentMemoryId: nil, rootMemoryId: "e228",
                                  forgetAfter: past, forgetReason: nil, history: [])
        XCTAssertFalse(MemoryFactFilter.isActive(expired),
                       "TTL-expired memories must not appear in answers")
    }
}

final class A112RegressionTests: XCTestCase {
    func testA112_lifecycleEventsRenderable() {
        let events = SpanResolver.lifecycleEvents(branch: .routeAmbiguity)
        XCTAssertFalse(events.isEmpty)
        var state = NotchState(phase: .input, query: "q112", answer: "", sources: [])
        for e in events { state = NotchReducer.apply(e, to: state) }
        let ok = !state.answer.isEmpty || state.terminal != nil || !state.reasoning.isEmpty || state.phase == .searching
        XCTAssertTrue(ok, "NotchReducer must render .routeAmbiguity")
    }
}

final class A141RegressionTests: XCTestCase {
    func testA141_citationIntegrity() {
        let ev = [Retrieved(memory: "User uses Bazel.", similarity: 0.9, source: .init(docId: "d141", path: "/f.md", title: "Notes"))]
        XCTAssertTrue(TimeWindow.citationIntegritySupported("User uses Bazel [Notes].", evidence: ev))
        XCTAssertFalse(TimeWindow.citationIntegritySupported("User uses CMake [Notes].", evidence: ev))
    }
    func testA141_unsupportedAnswerEvent() {
        XCTAssertEqual(TimeWindow.unsupportedAnswerEvents(), [.state(.unsupportedAnswer)])
    }
}
final class A199RegressionTests: XCTestCase {
    func testA199_ingest() {
        XCTAssertEqual(ScopeClassifier.indexingTerminalState(path:"/a.pdf"),.indexing(path:"/a.pdf"))
        XCTAssertEqual(ScopeClassifier.ingestionSelfHealSafe(orphanIds:["x",""]),["x"])
    }
}

final class A257RegressionTests: XCTestCase {
    func testA257_dreamingDoesNotDuplicateSynthesis() {
        let existing = [MemoryEntry(id: "s257", memory: "Synthesis 257.", version: 1,
                                    isLatest: true, isForgotten: false, isStatic: false,
                                    parentMemoryId: nil, rootMemoryId: "s257",
                                    forgetAfter: nil, forgetReason: nil, history: [])]
        XCTAssertFalse(Coverage.dreamingSafeSynthesis("Synthesis 257.", existing: existing,
                                                      constituents: ["fact 257"]),
                       "dreaming must not duplicate existing syntheses")
        XCTAssertTrue(Coverage.dreamingSafeSynthesis("New synthesis 257.", existing: existing,
                                                     constituents: ["fact 257"]),
                      "novel synthesis with constituent grounding is allowed")
    }
}
final class A170RegressionTests: XCTestCase { func testA170_x() { XCTAssertEqual(HeuristicRouter.indexingTerminalState(path:"/p"),.indexing(path:"/p")) } }

final class A83RegressionTests: XCTestCase {
    func testA83_lifecycleEventsRenderable() {
        let events = ScopeClassifier.lifecycleEvents(branch: .routeAmbiguity)
        XCTAssertFalse(events.isEmpty)
        var state = NotchState(phase: .input, query: "q83", answer: "", sources: [])
        for e in events { state = NotchReducer.apply(e, to: state) }
        XCTAssertTrue(!state.answer.isEmpty || state.terminal != nil || !state.reasoning.isEmpty || state.phase == .searching)
    }
}

/// A-025: Profile public types serve M3 identity preamble.
final class ProfileDocTests: XCTestCase {
    func testProfileDedupeNormalizesIdentityFacts() {
        XCTAssertEqual(ProfileDedupe.normalize("  Prefers Bazel!  "), "prefers bazel")
    }
}
