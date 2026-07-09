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
