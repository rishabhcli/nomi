import XCTest
@testable import MnemoOrchestrator

/// Agent I product-doc enforcement: UI.md, PLAN.md, and docs/product/* contracts
/// are tested here so documentation cannot drift from code.
final class ProductDocTests: XCTestCase {

    // MARK: - UI.md §7 motion tokens

    func testMotionTokensMatchUIContract() {
        // Canonical values from Sources/MnemoApp/Motion.swift — tested via contract mirror.
        let expected: [(String, Double, Double)] = [
            ("summon", 0.36, 0.84),
            ("grow", 0.32, 0.88),
            ("collapse", 0.30, 0.90),
            ("glyph", 0.25, 0.80),
        ]
        XCTAssertEqual(ProductDocContract.motionTokens.count, expected.count)
        for (i, e) in expected.enumerated() {
            let t = ProductDocContract.motionTokens[i]
            XCTAssertEqual(t.name, e.0)
            XCTAssertEqual(t.response, e.1, accuracy: 0.001)
            XCTAssertEqual(t.damping, e.2, accuracy: 0.001)
        }
        XCTAssertEqual(ProductDocContract.dissolveDuration, 0.20, accuracy: 0.001)
        XCTAssertEqual(ProductDocContract.revealDuration, 0.22, accuracy: 0.001)
        XCTAssertEqual(ProductDocContract.staggerSeconds, 0.06, accuracy: 0.001)
    }

    // MARK: - UI.md §4 surface dimensions

    func testSurfaceDimensionsMatchUIContract() {
        XCTAssertEqual(ProductDocContract.inputWidth, 520, accuracy: 0.5)
        XCTAssertEqual(ProductDocContract.bottomRadius, 46, accuracy: 0.5)
        XCTAssertEqual(ProductDocContract.idleRadius, 9, accuracy: 0.5)
    }

    // MARK: - UI.md §12 orb shader

    func testOrbUniformsMatchUIContract() {
        XCTAssertEqual(OrbUniforms.maxFill, ProductDocContract.orbMaxFill, accuracy: 0.001)
        XCTAssertEqual(OrbUniforms.idleFlow, ProductDocContract.orbIdleFlow, accuracy: 0.001)
        let high = OrbUniforms(amplitude: 0.95)
        XCTAssertLessThanOrEqual(high.waveHeight, ProductDocContract.orbMaxFill + 0.001)
    }

    // MARK: - UI.md §9 terminal copy (AT-M12.7)

    func testTerminalCopyMatchesUIContract() {
        let terminals: [TerminalState] = [
            .indexing(path: "/doc.pdf"),
            .empty(nearest: []),
            .emptyCorpus,
            .modelNotLoaded(model: "gpt-oss:20b"),
            .engineUnreachable,
            .unsupportedAnswer,
        ]
        let keys = ["indexing", "empty", "emptyCorpus", "modelNotLoaded", "engineUnreachable", "unsupportedAnswer"]
        for (terminal, key) in zip(terminals, keys) {
            let msg = NotchReducer.message(for: terminal)
            let snippet = ProductDocContract.terminalMessageSnippet(for: key)
            XCTAssertFalse(msg.isEmpty, "\(key) must render")
            XCTAssertTrue(msg.contains(snippet) || msg.lowercased().contains(snippet.lowercased()),
                          "\(key): expected snippet '\(snippet)' in '\(msg)'")
        }
    }

    func testTerminalRecoveryActionsDefined() {
        XCTAssertEqual(TerminalState.modelNotLoaded(model: "m").recovery, .loadModel)
        XCTAssertEqual(TerminalState.engineUnreachable.recovery, .restartEngine)
        XCTAssertEqual(TerminalState.empty(nearest: []).recovery, .broaden)
        XCTAssertEqual(TerminalState.unsupportedAnswer.recovery, .broaden)
        XCTAssertEqual(TerminalState.indexing(path: "/x").recovery, .waitAndRetry)
        XCTAssertEqual(TerminalState.emptyCorpus.recovery, .addFiles)
    }

    // MARK: - PLAN.md Appendix B metrics

    func testAppendixBMetricsComplete() {
        XCTAssertEqual(ProductDocContract.appendixBMetrics.count, 11)
        XCTAssertTrue(ProductDocContract.appendixBMetrics.contains("egress_blocked_count"))
        XCTAssertTrue(ProductDocContract.appendixBMetrics.contains("verification_pass_rate"))
    }

    // MARK: - Shared/ Codable alignment

    func testSourceLocatorCodingKeys() {
        // Verify CodingKeys exist on SourceLocator by round-trip encode
        let loc = SourceLocator(docId: "d", path: "/p", title: "t", charStart: 0, charEnd: 5)
        let data = try! JSONEncoder().encode(loc)
        let json = String(data: data, encoding: .utf8)!
        XCTAssertTrue(json.contains("doc_id"))
        XCTAssertTrue(json.contains("char_start"))
        XCTAssertTrue(json.contains("char_end"))
    }

    func testMemoryEntryDecodesEngineJSON() throws {
        let json = """
        {"id":"m1","memory":"fact","version":1,"isLatest":true,"isForgotten":false,
         "isStatic":false,"parentMemoryId":null,"rootMemoryId":"m1",
         "forgetAfter":null,"forgetReason":null,"history":[],"documentIds":["d1"]}
        """
        let entry = try JSONDecoder().decode(MemoryEntry.self, from: Data(json.utf8))
        XCTAssertEqual(entry.id, "m1")
        XCTAssertEqual(entry.documentIds, ["d1"])
    }

    // MARK: - Expressiveness timeline (docs/product/expressiveness-timeline.md)

    func testAnswerShapesAreDistinct() {
        XCTAssertEqual(ProductDocContract.answerShapes.count, 5)
        let shapes: [AnswerShape] = [.definition, .comparison, .timeline, .list, .synthesis]
        let directives = shapes.map { ResponseStyle.directive(shape: $0, tone: .balanced) }
        XCTAssertEqual(Set(directives).count, 5)
    }

    func testTimelineShapeProducesNumberedList() {
        let shaped = NotchReducer.expressivenessShape(["May 5 planned", "June 2 actual"], as: .timeline)
        XCTAssertTrue(shaped.contains("1."))
        XCTAssertTrue(shaped.contains("2."))
    }

    // MARK: - Helpfulness refusal copy

    func testRefusalCopyDoesNotInvent() {
        let msg = NotchReducer.message(for: .unsupportedAnswer)
        XCTAssertTrue(msg.lowercased().contains("won't guess") || msg.lowercased().contains("ground"))
        let empty = NotchReducer.message(for: .empty(nearest: []))
        XCTAssertTrue(empty.lowercased().contains("broadening") || empty.lowercased().contains("matches"))
    }

    // MARK: - Privacy indicator semantics

    func testPrivacyIndicatorCleanWhenZeroEgress() async {
        let guard0 = EgressGuard()
        _ = await guard0.beginQueryWindow()
        let indicator = await PrivacyIndicator.from(guard0)
        guard case .clean = indicator else {
            return XCTFail("expected clean with zero egress")
        }
    }

    func testPrivacyIndicatorEgressWhenBlocked() async {
        let guard0 = EgressGuard()
        _ = await guard0.beginQueryWindow()
        await guard0.recordAttempt(host: "api.example.com")
        let indicator = await PrivacyIndicator.from(guard0)
        guard case .egressDetected(let count) = indicator else {
            return XCTFail("expected egressDetected")
        }
        XCTAssertEqual(count, 1)
    }

    // MARK: - Hardware tier SLA

    func testHardwareTiersHonest() {
        XCTAssertEqual(ProductDocContract.hardwareTiers.count, 2)
        let rec = ProductDocContract.hardwareTiers.first { $0.name == "recommended" }!
        XCTAssertEqual(rec.minRAMGB, 16)
        XCTAssertEqual(rec.model, "gpt-oss:20b")
        let floor = ProductDocContract.hardwareTiers.first { $0.name == "floor" }!
        XCTAssertEqual(floor.minRAMGB, 12)
        XCTAssertTrue(floor.model.contains("4b") || floor.model.contains("8b"))
    }

    func testSLATargetsFromConfig() {
        XCTAssertEqual(ProductDocContract.slaFirstTokenMs, 1500)
        XCTAssertEqual(ProductDocContract.slaSourcesRenderMs, 1000)
    }

    // MARK: - Comparison table axes

    func testComparisonAxesCoverSiriGap() {
        XCTAssertTrue(ProductDocContract.comparisonAxes.contains("cross_document_synthesis"))
        XCTAssertTrue(ProductDocContract.comparisonAxes.contains("airplane_mode_hard_questions"))
        XCTAssertTrue(ProductDocContract.comparisonAxes.contains("profile_inspectable"))
    }

    // MARK: - BS-M / AT-M milestone IDs exist in contract

    func testAcceptanceMilestoneIDsComplete() {
        XCTAssertEqual(ProductDocContract.acceptanceTestMilestones.count, 13) // M0…M12
        XCTAssertEqual(ProductDocContract.beatsSiriMilestones.count, 13)
        XCTAssertEqual(ProductDocContract.acceptanceTestMilestones.first, "AT-M0")
        XCTAssertEqual(ProductDocContract.beatsSiriMilestones.last, "BS-M12")
    }

    // MARK: - UI.md exists (verify command from I-* prompts)

    func testUIMDExists() {
        let path = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("UI.md")
        XCTAssertTrue(FileManager.default.fileExists(atPath: path.path))
        let content = try! String(contentsOf: path, encoding: .utf8)
        XCTAssertFalse(content.contains("TBD"))
        XCTAssertTrue(content.contains("Motion.summon"))
        XCTAssertTrue(content.contains("OrbUniforms"))
    }

    func testPLANMDHasATMilestones() throws {
        let path = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("PLAN.md")
        let content = try String(contentsOf: path, encoding: .utf8)
        XCTAssertFalse(content.contains("TBD"))
        XCTAssertTrue(content.contains("AT-M0"))
        XCTAssertTrue(content.contains("BS-M12"))
    }
}
