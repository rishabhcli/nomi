import XCTest
@testable import MnemoOrchestrator

final class ProfileDecodeTests: XCTestCase {
    // Captured from the live engine: POST /v4/profile
    static let json = """
    {"profile":{"static":["User's name is Alex."],
      "dynamic":["User's favorite build tool is Bazel.","User switched to Bazel in March 2025."]},
     "searchResults":{"results":[
       {"id":"m1","memory":"User's favorite build tool is Bazel.","similarity":0.78,
        "filepath":null,
        "documents":[{"id":"d1","title":"# Build tooling notes"}]}]}}
    """

    func testDecodesProfileEnvelope() throws {
        let p = try JSONDecoder().decode(EngineClient.ProfileEnvelope.self, from: Data(Self.json.utf8))
        XCTAssertEqual(p.profile.static, ["User's name is Alex."])
        XCTAssertEqual(p.profile.dynamic.count, 2)
        XCTAssertEqual(p.searchResults.results.count, 1)
    }
}

final class ProfileDedupeTests: XCTestCase {
    func testDedupePriorityStaticOverDynamicOverSearch() {
        let mem = Retrieved(memory: "User's favorite build tool is Bazel.", similarity: 0.7,
                            source: .init(docId: "d1", path: "/f.md", title: "f"))
        let p = Profile(
            statics: ["User's favorite build tool is Bazel.", "User's name is Alex."],
            dynamics: ["User's favorite build tool is Bazel.",   // dup of static → dropped
                       "User switched to Bazel in March 2025."],
            memories: [mem,                                       // dup of static → dropped
                       Retrieved(memory: "User used CMake for four years.", similarity: 0.6,
                                 source: .init(docId: "d1", path: "/f.md", title: "f"))])
        let d = ProfileDedupe.dedupe(p)
        XCTAssertEqual(d.statics.count, 2)
        XCTAssertEqual(d.dynamics, ["User switched to Bazel in March 2025."])
        XCTAssertEqual(d.memories.map(\.memory), ["User used CMake for four years."])
    }

    func testNormalizationIgnoresCaseAndPunctuation() {
        let p = Profile(statics: ["User prefers dark mode."],
                        dynamics: ["user prefers DARK MODE"],
                        memories: [])
        let d = ProfileDedupe.dedupe(p)
        XCTAssertTrue(d.dynamics.isEmpty, "case/punct variant is the same fact")
    }
}

final class A201RegressionTests: XCTestCase {
    func testA201_forgottenFactExcludedAfterForget() {
        let forgotten = MemoryEntry(id: "m201", memory: "Forgotten fact 201.", version: 1,
                                    isLatest: true, isForgotten: true, isStatic: false,
                                    parentMemoryId: nil, rootMemoryId: "m201",
                                    forgetAfter: nil, forgetReason: "user retraction", history: [])
        let active = MemoryEntry(id: "m201b", memory: "Active fact 201.", version: 1,
                                 isLatest: true, isForgotten: false, isStatic: false,
                                 parentMemoryId: nil, rootMemoryId: "m201b",
                                 forgetAfter: nil, forgetReason: nil, history: [])
        let filtered = MediaCompanion.memoryDynamicsFilter([forgotten, active])
        XCTAssertEqual(filtered.map(\.id), ["m201b"],
                       "re-asked queries must not surface facts retracted via /forget")
    }

    func testA201_ttlExpiredExcluded() {
        let past = ISO8601DateFormatter().string(from: Date().addingTimeInterval(-3600))
        let expired = MemoryEntry(id: "e201", memory: "TTL fact 201.", version: 1,
                                  isLatest: true, isForgotten: false, isStatic: false,
                                  parentMemoryId: nil, rootMemoryId: "e201",
                                  forgetAfter: past, forgetReason: nil, history: [])
        XCTAssertFalse(MediaCompanion.memoryDynamicsActive(expired),
                       "TTL-expired memories must not appear in answers")
    }
}

final class A230RegressionTests: XCTestCase {
    func testA230_forgottenFactExcludedAfterForget() {
        let forgotten = MemoryEntry(id: "m230", memory: "Forgotten fact 230.", version: 1,
                                    isLatest: true, isForgotten: true, isStatic: false,
                                    parentMemoryId: nil, rootMemoryId: "m230",
                                    forgetAfter: nil, forgetReason: "user retraction", history: [])
        let active = MemoryEntry(id: "m230b", memory: "Active fact 230.", version: 1,
                                 isLatest: true, isForgotten: false, isStatic: false,
                                 parentMemoryId: nil, rootMemoryId: "m230b",
                                 forgetAfter: nil, forgetReason: nil, history: [])
        let filtered = ColdArchive.memoryDynamicsFilter([forgotten, active])
        XCTAssertEqual(filtered.map(\.id), ["m230b"],
                       "re-asked queries must not surface facts retracted via /forget")
    }

    func testA230_ttlExpiredExcluded() {
        let past = ISO8601DateFormatter().string(from: Date().addingTimeInterval(-3600))
        let expired = MemoryEntry(id: "e230", memory: "TTL fact 230.", version: 1,
                                  isLatest: true, isForgotten: false, isStatic: false,
                                  parentMemoryId: nil, rootMemoryId: "e230",
                                  forgetAfter: past, forgetReason: nil, history: [])
        XCTAssertFalse(ColdArchive.memoryDynamicsActive(expired),
                       "TTL-expired memories must not appear in answers")
    }
}

final class A114RegressionTests: XCTestCase {
    func testA114_lifecycleEventsRenderable() {
        let events = AgenticGrep.lifecycleEvents(branch: .retry)
        XCTAssertFalse(events.isEmpty)
        var state = NotchState(phase: .input, query: "q114", answer: "", sources: [])
        for e in events { state = NotchReducer.apply(e, to: state) }
        let ok = !state.answer.isEmpty || state.terminal != nil || !state.reasoning.isEmpty || state.phase == .searching
        XCTAssertTrue(ok, "NotchReducer must render .retry")
    }
}

final class A143RegressionTests: XCTestCase {
    func testA143_citationIntegrity() {
        let ev = [Retrieved(memory: "User uses Bazel.", similarity: 0.9, source: .init(docId: "d143", path: "/f.md", title: "Notes"))]
        XCTAssertTrue(ResponseStyle.citationIntegritySupported("User uses Bazel [Notes].", evidence: ev))
        XCTAssertFalse(ResponseStyle.citationIntegritySupported("User uses CMake [Notes].", evidence: ev))
    }
    func testA143_unsupportedAnswerEvent() {
        XCTAssertEqual(ResponseStyle.unsupportedAnswerEvents(), [.state(.unsupportedAnswer)])
    }
}

final class A259RegressionTests: XCTestCase {
    func testA259_dreamingDoesNotDuplicateSynthesis() {
        let existing = [MemoryEntry(id: "s259", memory: "Synthesis 259.", version: 1,
                                    isLatest: true, isForgotten: false, isStatic: false,
                                    parentMemoryId: nil, rootMemoryId: "s259",
                                    forgetAfter: nil, forgetReason: nil, history: [])]
        XCTAssertFalse(ActionExtractor.dreamingSafeSynthesis("Synthesis 259.", existing: existing,
                                                      constituents: ["fact 259"]),
                       "dreaming must not duplicate existing syntheses")
        XCTAssertTrue(ActionExtractor.dreamingSafeSynthesis("New synthesis 259.", existing: existing,
                                                     constituents: ["fact 259"]),
                      "novel synthesis with constituent grounding is allowed")
    }
}
final class A172RegressionTests: XCTestCase { func testA172_x() { XCTAssertEqual(QueryService.indexingTerminalState(path:"/p"),.indexing(path:"/p")) } }

final class A85RegressionTests: XCTestCase {
    func testA85_lifecycleEventsRenderable() {
        let events = AnswerCache.lifecycleEvents(branch: .retry)
        XCTAssertFalse(events.isEmpty)
        var state = NotchState(phase: .input, query: "q85", answer: "", sources: [])
        for e in events { state = NotchReducer.apply(e, to: state) }
        XCTAssertTrue(!state.answer.isEmpty || state.terminal != nil || !state.reasoning.isEmpty || state.phase == .searching)
    }
}

/// A-027 audit: WorkScheduler yields for background during interactive queries.
final class WorkSchedulerAuditTests: XCTestCase {
    func testBackgroundYieldsHintDuringInteractive() async {
        let sched = WorkScheduler()
        let token = await sched.beginInteractive()
        XCTAssertTrue(await sched.shouldBackgroundYield)
        await sched.endInteractive(token)
    }
}
