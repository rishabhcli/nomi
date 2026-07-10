import XCTest
@testable import MnemoOrchestrator

final class CommandParserTests: XCTestCase {
    func testPlainTextIsAQuery() {
        XCTAssertEqual(CommandParser.parse("what is my build tool?"), .query("what is my build tool?"))
    }

    func testHelpAndInspectAndClear() {
        XCTAssertEqual(CommandParser.parse("/help"), .command(.help))
        XCTAssertEqual(CommandParser.parse("/inspect"), .command(.inspect))
        XCTAssertEqual(CommandParser.parse("/profile"), .command(.profile))
        XCTAssertEqual(CommandParser.parse("/clear"), .command(.clear))
    }

    func testForgetCarriesTheFactText() {
        XCTAssertEqual(CommandParser.parse("/forget I have a boat named Serenity"),
                       .command(.forget("I have a boat named Serenity")))
        // No argument → treated as help (nothing to forget).
        XCTAssertEqual(CommandParser.parse("/forget"), .command(.help))
    }

    func testScopeCarriesContainer() {
        XCTAssertEqual(CommandParser.parse("/scope work"), .command(.scope("work")))
        XCTAssertEqual(CommandParser.parse("/scope   personal  "), .command(.scope("personal")))
    }

    func testLeadingWhitespaceAndCaseTolerant() {
        XCTAssertEqual(CommandParser.parse("  /HELP "), .command(.help))
        XCTAssertEqual(CommandParser.parse("/Forget X"), .command(.forget("X")))
    }

    func testUnknownCommandFallsBackToHelp() {
        XCTAssertEqual(CommandParser.parse("/wat"), .command(.help))
    }

    func testBareSlashIsQuery() {
        // A lone "/" or text that merely contains a slash is a normal query.
        XCTAssertEqual(CommandParser.parse("and/or which is better?"), .query("and/or which is better?"))
    }

    func testHelpTextListsCommands() {
        let help = CommandParser.helpText
        for token in ["/help", "/forget", "/scope", "/inspect", "/profile", "/clear"] {
            XCTAssertTrue(help.contains(token), "help text missing \(token)")
        }
    }
}

final class A202RegressionTests: XCTestCase {
    func testA202_forgottenFactExcludedAfterForget() {
        let forgotten = MemoryEntry(id: "m202", memory: "Forgotten fact 202.", version: 1,
                                    isLatest: true, isForgotten: true, isStatic: false,
                                    parentMemoryId: nil, rootMemoryId: "m202",
                                    forgetAfter: nil, forgetReason: "user retraction", history: [])
        let active = MemoryEntry(id: "m202b", memory: "Active fact 202.", version: 1,
                                 isLatest: true, isForgotten: false, isStatic: false,
                                 parentMemoryId: nil, rootMemoryId: "m202b",
                                 forgetAfter: nil, forgetReason: nil, history: [])
        let filtered = LocalExtractor.memoryDynamicsFilter([forgotten, active])
        XCTAssertEqual(filtered.map(\.id), ["m202b"],
                       "re-asked queries must not surface facts retracted via /forget")
    }

    func testA202_ttlExpiredExcluded() {
        let past = ISO8601DateFormatter().string(from: Date().addingTimeInterval(-3600))
        let expired = MemoryEntry(id: "e202", memory: "TTL fact 202.", version: 1,
                                  isLatest: true, isForgotten: false, isStatic: false,
                                  parentMemoryId: nil, rootMemoryId: "e202",
                                  forgetAfter: past, forgetReason: nil, history: [])
        XCTAssertFalse(LocalExtractor.memoryDynamicsActive(expired),
                       "TTL-expired memories must not appear in answers")
    }
}

final class A231RegressionTests: XCTestCase {
    func testA231_forgottenFactExcludedAfterForget() {
        let forgotten = MemoryEntry(id: "m231", memory: "Forgotten fact 231.", version: 1,
                                    isLatest: true, isForgotten: true, isStatic: false,
                                    parentMemoryId: nil, rootMemoryId: "m231",
                                    forgetAfter: nil, forgetReason: "user retraction", history: [])
        let active = MemoryEntry(id: "m231b", memory: "Active fact 231.", version: 1,
                                 isLatest: true, isForgotten: false, isStatic: false,
                                 parentMemoryId: nil, rootMemoryId: "m231b",
                                 forgetAfter: nil, forgetReason: nil, history: [])
        let filtered = LLMSynthesizer.memoryDynamicsFilter([forgotten, active])
        XCTAssertEqual(filtered.map(\.id), ["m231b"],
                       "re-asked queries must not surface facts retracted via /forget")
    }

    func testA231_ttlExpiredExcluded() {
        let past = ISO8601DateFormatter().string(from: Date().addingTimeInterval(-3600))
        let expired = MemoryEntry(id: "e231", memory: "TTL fact 231.", version: 1,
                                  isLatest: true, isForgotten: false, isStatic: false,
                                  parentMemoryId: nil, rootMemoryId: "e231",
                                  forgetAfter: past, forgetReason: nil, history: [])
        XCTAssertFalse(LLMSynthesizer.memoryDynamicsActive(expired),
                       "TTL-expired memories must not appear in answers")
    }
}

final class A115RegressionTests: XCTestCase {
    func testA115_lifecycleEventsRenderable() {
        let events = KeywordBackstop.lifecycleEvents(branch: .routeAmbiguity)
        XCTAssertFalse(events.isEmpty)
        var state = NotchState(phase: .input, query: "q115", answer: "", sources: [])
        for e in events { state = NotchReducer.apply(e, to: state) }
        let ok = !state.answer.isEmpty || state.terminal != nil || !state.reasoning.isEmpty || state.phase == .searching
        XCTAssertTrue(ok, "NotchReducer must render .routeAmbiguity")
    }
}

final class A144RegressionTests: XCTestCase {
    func testA144_citationIntegrity() {
        let ev = [Retrieved(memory: "User uses Bazel.", similarity: 0.9, source: .init(docId: "d144", path: "/f.md", title: "Notes"))]
        XCTAssertTrue(FollowUpSuggester.citationIntegritySupported("User uses Bazel [Notes].", evidence: ev))
        XCTAssertFalse(FollowUpSuggester.citationIntegritySupported("User uses CMake [Notes].", evidence: ev))
    }
    func testA144_unsupportedAnswerEvent() {
        XCTAssertEqual(FollowUpSuggester.unsupportedAnswerEvents(), [.state(.unsupportedAnswer)])
    }
}

final class A260RegressionTests: XCTestCase {
    func testA260_dreamingDoesNotDuplicateSynthesis() {
        let existing = [MemoryEntry(id: "s260", memory: "Synthesis 260.", version: 1,
                                    isLatest: true, isForgotten: false, isStatic: false,
                                    parentMemoryId: nil, rootMemoryId: "s260",
                                    forgetAfter: nil, forgetReason: nil, history: [])]
        XCTAssertFalse(CorpusSuggester.dreamingSafeSynthesis("Synthesis 260.", existing: existing,
                                                      constituents: ["fact 260"]),
                       "dreaming must not duplicate existing syntheses")
        XCTAssertTrue(CorpusSuggester.dreamingSafeSynthesis("New synthesis 260.", existing: existing,
                                                     constituents: ["fact 260"]),
                      "novel synthesis with constituent grounding is allowed")
    }
}
final class A173RegressionTests: XCTestCase { func testA173_x() { XCTAssertEqual(EngineClient.indexingTerminalState(path:"/p"),.indexing(path:"/p")) } }

final class A86RegressionTests: XCTestCase {
    func testA86_lifecycleEventsRenderable() {
        let events = QueryHistory.lifecycleEvents(branch: .routeAmbiguity)
        XCTAssertFalse(events.isEmpty)
        var state = NotchState(phase: .input, query: "q86", answer: "", sources: [])
        for e in events { state = NotchReducer.apply(e, to: state) }
        XCTAssertTrue(!state.answer.isEmpty || state.terminal != nil || !state.reasoning.isEmpty || state.phase == .searching)
    }
}

/// A-028 invariant: NotchReducer is a pure state machine with no URL construction.
final class NotchReducerInvariantTests: XCTestCase {
    func testRoutedClearsStaleTerminal() {
        var s = NotchState(phase: .state, query: "q", answer: "old", sources: [],
                           terminal: .engineUnreachable)
        s = NotchReducer.apply(.routed(intent: "lookup", effort: "medium"), to: s)
        XCTAssertNil(s.terminal)
        XCTAssertEqual(s.phase, .searching)
    }
}
