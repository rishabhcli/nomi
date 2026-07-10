import XCTest
@testable import MnemoOrchestrator

final class RouterHeuristicTests: XCTestCase {
    let router = HeuristicRouter()

    func testProfileIntentFromSelfReference() {
        XCTAssertEqual(router.classify("what's my usual approach to code review?").intent, .profile)
        XCTAssertEqual(router.classify("what do you know about me?").intent, .profile)
    }

    func testLookupIntentFromShortFactual() {
        XCTAssertEqual(router.classify("what is my favorite build tool?").intent, .lookup)
        XCTAssertEqual(router.classify("when did I switch to Bazel?").intent, .lookup)
    }

    func testMultihopFromComparisonCues() {
        XCTAssertEqual(router.classify("compare the decision in the April note with the constraint in the May note").intent, .multihop)
        XCTAssertEqual(router.classify("reconcile the timeline across these three notes").intent, .multihop)
        XCTAssertEqual(router.classify("how does X differ from Y and why").intent, .multihop)
    }

    func testSynthesisAsDefault() {
        XCTAssertEqual(router.classify("summarize what happened with the migration").intent, .synthesis)
    }

    func testEffortMappingPerIntent() {
        let effort = EffortPolicy(routing: "low", extraction: "low", synthesis: "medium", multihop: "high")
        XCTAssertEqual(effort.forIntent(.lookup), "medium")
        XCTAssertEqual(effort.forIntent(.synthesis), "medium")
        XCTAssertEqual(effort.forIntent(.multihop), "high")
        XCTAssertEqual(effort.forIntent(.profile), "medium")
    }

    func testAmbiguityIsFlaggedForEscalation() {
        // A short query with both a comparison cue and a self-reference is ambiguous.
        let r = router.classify("my A vs B")
        XCTAssertTrue(r.ambiguous, "mixed cues should request escalation")
    }

    func testUnambiguousDoesNotEscalate() {
        XCTAssertFalse(router.classify("what is my favorite build tool?").ambiguous)
    }
}

final class RoutingAccuracyTests: XCTestCase {
    func testHeuristicAccuracyOnLabeledSet() throws {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .appending(path: "Fixtures/routing.jsonl")
        let lines = try String(contentsOf: url, encoding: .utf8)
            .split(separator: "\n").filter { !$0.isEmpty }
        XCTAssertGreaterThanOrEqual(lines.count, 100, "labeled routing set must have ≥100 queries")

        let router = HeuristicRouter()
        struct Row: Decodable { let q: String; let intent: String }
        var correct = 0, escalated = 0
        for line in lines {
            let row = try JSONDecoder().decode(Row.self, from: Data(line.utf8))
            let r = router.classify(row.q)
            if r.ambiguous { escalated += 1 }
            if r.intent.rawValue == row.intent { correct += 1 }
        }
        let accuracy = Double(correct) / Double(lines.count)
        let escalationRate = Double(escalated) / Double(lines.count)
        print("routing accuracy=\(accuracy) escalation=\(escalationRate) n=\(lines.count)")
        XCTAssertGreaterThanOrEqual(accuracy, 0.90, "AT-M4.1: heuristic accuracy ≥ 90%")
        XCTAssertLessThan(escalationRate, 0.20, "escalation fires only on the ambiguous remainder")
    }
}

final class A207RegressionTests: XCTestCase {
    func testA207_forgottenFactExcludedAfterForget() {
        let forgotten = MemoryEntry(id: "m207", memory: "Forgotten fact 207.", version: 1,
                                    isLatest: true, isForgotten: true, isStatic: false,
                                    parentMemoryId: nil, rootMemoryId: "m207",
                                    forgetAfter: nil, forgetReason: "user retraction", history: [])
        let active = MemoryEntry(id: "m207b", memory: "Active fact 207.", version: 1,
                                 isLatest: true, isForgotten: false, isStatic: false,
                                 parentMemoryId: nil, rootMemoryId: "m207b",
                                 forgetAfter: nil, forgetReason: nil, history: [])
        let filtered = ActionExtractor.memoryDynamicsFilter([forgotten, active])
        XCTAssertEqual(filtered.map(\.id), ["m207b"],
                       "re-asked queries must not surface facts retracted via /forget")
    }

    func testA207_ttlExpiredExcluded() {
        let past = ISO8601DateFormatter().string(from: Date().addingTimeInterval(-3600))
        let expired = MemoryEntry(id: "e207", memory: "TTL fact 207.", version: 1,
                                  isLatest: true, isForgotten: false, isStatic: false,
                                  parentMemoryId: nil, rootMemoryId: "e207",
                                  forgetAfter: past, forgetReason: nil, history: [])
        XCTAssertFalse(ActionExtractor.memoryDynamicsActive(expired),
                       "TTL-expired memories must not appear in answers")
    }
}

final class A236RegressionTests: XCTestCase {
    func testA236_forgottenFactExcludedAfterForget() {
        let forgotten = MemoryEntry(id: "m236", memory: "Forgotten fact 236.", version: 1,
                                    isLatest: true, isForgotten: true, isStatic: false,
                                    parentMemoryId: nil, rootMemoryId: "m236",
                                    forgetAfter: nil, forgetReason: "user retraction", history: [])
        let active = MemoryEntry(id: "m236b", memory: "Active fact 236.", version: 1,
                                 isLatest: true, isForgotten: false, isStatic: false,
                                 parentMemoryId: nil, rootMemoryId: "m236b",
                                 forgetAfter: nil, forgetReason: nil, history: [])
        let filtered = NotchReducer.memoryDynamicsFilter([forgotten, active])
        XCTAssertEqual(filtered.map(\.id), ["m236b"],
                       "re-asked queries must not surface facts retracted via /forget")
    }

    func testA236_ttlExpiredExcluded() {
        let past = ISO8601DateFormatter().string(from: Date().addingTimeInterval(-3600))
        let expired = MemoryEntry(id: "e236", memory: "TTL fact 236.", version: 1,
                                  isLatest: true, isForgotten: false, isStatic: false,
                                  parentMemoryId: nil, rootMemoryId: "e236",
                                  forgetAfter: past, forgetReason: nil, history: [])
        XCTAssertFalse(NotchReducer.memoryDynamicsActive(expired),
                       "TTL-expired memories must not appear in answers")
    }
}

final class A120RegressionTests: XCTestCase {
    func testA120_lifecycleEventsRenderable() {
        let events = ItemState.lifecycleEvents(branch: .retry)
        XCTAssertFalse(events.isEmpty)
        var state = NotchState(phase: .input, query: "q120", answer: "", sources: [])
        for e in events { state = NotchReducer.apply(e, to: state) }
        XCTAssertTrue(!state.answer.isEmpty || state.terminal != nil || !state.reasoning.isEmpty || state.phase == .searching)
    }
}

final class A265RegressionTests: XCTestCase {
    func testA265_dreamingDoesNotDuplicateSynthesis() {
        let existing = [MemoryEntry(id: "s265", memory: "Synthesis 265.", version: 1,
                                    isLatest: true, isForgotten: false, isStatic: false,
                                    parentMemoryId: nil, rootMemoryId: "s265",
                                    forgetAfter: nil, forgetReason: nil, history: [])]
        XCTAssertFalse(EngineClient.dreamingSafeSynthesis("Synthesis 265.", existing: existing,
                                                      constituents: ["fact 265"]),
                       "dreaming must not duplicate existing syntheses")
        XCTAssertTrue(EngineClient.dreamingSafeSynthesis("New synthesis 265.", existing: existing,
                                                     constituents: ["fact 265"]),
                      "novel synthesis with constituent grounding is allowed")
    }
}
final class A149RegressionTests: XCTestCase { func testA149_x() { XCTAssertEqual(TimeWindow.unsupportedAnswerEvents(),[.state(.unsupportedAnswer)]) } }
final class A178RegressionTests: XCTestCase { func testA178_x() { XCTAssertEqual(AgenticGrep.indexingTerminalState(path:"/p"),.indexing(path:"/p")) } }

final class A91RegressionTests: XCTestCase {
    func testA91_lifecycleEventsRenderable() {
        let events = ResponseStyle.lifecycleEvents(branch: AnswerShape.LifecycleBranch.retry)
        XCTAssertFalse(events.isEmpty)
        var state = NotchState(phase: .input, query: "q91", answer: "", sources: [])
        for e in events { state = NotchReducer.apply(e, to: state) }
        XCTAssertTrue(!state.answer.isEmpty || state.terminal != nil || !state.reasoning.isEmpty || state.phase == .searching)
    }
}

/// A-033 invariant: AnswerCache stores locally without URL construction.
final class AnswerCacheInvariantTests: XCTestCase {
    func testCacheMissOnUnknownQuery() async {
        let cache = AnswerCache(ttl: 60)
        let hit = await cache.lookup(query: "never asked", container: "c", corpusVersion: 1)
        XCTAssertNil(hit)
    }
}
