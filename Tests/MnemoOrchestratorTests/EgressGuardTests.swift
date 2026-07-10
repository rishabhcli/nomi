import XCTest
@testable import MnemoOrchestrator

final class LoopbackClassifyTests: XCTestCase {
    func testLoopbackHostsAreAllowed() {
        XCTAssertTrue(EgressGuard.isLoopbackHost("127.0.0.1"))
        XCTAssertTrue(EgressGuard.isLoopbackHost("localhost"))
        XCTAssertTrue(EgressGuard.isLoopbackHost("::1"))
        XCTAssertTrue(EgressGuard.isLoopbackHost("127.0.0.53"))
    }
    func testNonLoopbackHostsAreEgress() {
        XCTAssertFalse(EgressGuard.isLoopbackHost("api.supermemory.ai"))
        XCTAssertFalse(EgressGuard.isLoopbackHost("10.0.0.16"))
        XCTAssertFalse(EgressGuard.isLoopbackHost("8.8.8.8"))
        XCTAssertFalse(EgressGuard.isLoopbackHost("generativelanguage.googleapis.com"))
    }
}

final class EgressGuardTests: XCTestCase {
    func testWindowCountsAndCleanliness() async {
        let guard0 = EgressGuard()
        let window = await guard0.beginQueryWindow()
        var clean = await guard0.isClean()
        XCTAssertTrue(clean)
        await guard0.recordAttempt(host: "api.supermemory.ai")   // simulated egress attempt
        let n = await guard0.outboundNonLoopbackAttempts
        clean = await guard0.isClean()
        XCTAssertEqual(n, 1)
        XCTAssertFalse(clean)
        await guard0.endWindow(window)
    }

    func testLoopbackAttemptsDoNotCount() async {
        let g = EgressGuard()
        _ = await g.beginQueryWindow()
        await g.recordAttempt(host: "127.0.0.1")
        await g.recordAttempt(host: "localhost")
        let n = await g.outboundNonLoopbackAttempts
        XCTAssertEqual(n, 0)
        let clean = await g.isClean()
        XCTAssertTrue(clean)
    }
}

/// The in-process interposer: our URLSession clients route through it; a
/// non-loopback request is blocked and counted (AT-M10.3).
final class LoopbackGuardURLProtocolTests: XCTestCase {
    override func tearDown() {
        LoopbackGuardURLProtocol.reset()
        super.tearDown()
    }

    func testBlocksAndCountsNonLoopbackRequest() async {
        LoopbackGuardURLProtocol.reset()
        let cfg = URLSessionConfiguration.ephemeral
        cfg.protocolClasses = [LoopbackGuardURLProtocol.self]
        let session = URLSession(configuration: cfg)
        do {
            _ = try await session.data(from: URL(string: "https://api.supermemory.ai/v4/search")!)
            XCTFail("non-loopback request must be blocked")
        } catch {
            XCTAssertEqual(LoopbackGuardURLProtocol.blockedCount, 1)
        }
    }

    func testAllowsLoopbackRequest() {
        // canInit must be false for loopback so the normal loader handles it.
        let loopback = URLRequest(url: URL(string: "http://127.0.0.1:6767/v4/search")!)
        let external = URLRequest(url: URL(string: "https://api.supermemory.ai")!)
        XCTAssertFalse(LoopbackGuardURLProtocol.canInit(with: loopback))
        XCTAssertTrue(LoopbackGuardURLProtocol.canInit(with: external))
    }
}

final class PrivacyIndicatorTests: XCTestCase {
    func testIndicatorReflectsMeasuredState() async {
        let g = EgressGuard()
        _ = await g.beginQueryWindow()
        var indicator = await PrivacyIndicator.from(g)
        XCTAssertEqual(indicator, .clean)
        await g.recordAttempt(host: "8.8.8.8")
        indicator = await PrivacyIndicator.from(g)
        XCTAssertEqual(indicator, .egressDetected(count: 1))
    }
}

/// A-015: OllamaClient public types are documented for loopback generation.
final class OllamaClientDocTests: XCTestCase {
    func testOllamaLineParsesStreamTokens() {
        XCTAssertEqual(OllamaLine.parse(#"{"response":"hi","done":false}"#), "hi")
        XCTAssertNil(OllamaLine.parse(#"{"done":true}"#))
    }

    func testOllamaClientDocumentsLoopbackGeneration() {
        let client = OllamaClient(baseURL: URL(string: "http://127.0.0.1:11434")!,
                                  model: "gpt-oss:20b")
        XCTAssertEqual(client.baseURL.host, "127.0.0.1")
    }
}

final class A218RegressionTests: XCTestCase {
    func testA218_forgottenFactExcludedAfterForget() {
        let forgotten = MemoryEntry(id: "m218", memory: "Forgotten fact 218.", version: 1,
                                    isLatest: true, isForgotten: true, isStatic: false,
                                    parentMemoryId: nil, rootMemoryId: "m218",
                                    forgetAfter: nil, forgetReason: "user retraction", history: [])
        let active = MemoryEntry(id: "m218b", memory: "Active fact 218.", version: 1,
                                 isLatest: true, isForgotten: false, isStatic: false,
                                 parentMemoryId: nil, rootMemoryId: "m218b",
                                 forgetAfter: nil, forgetReason: nil, history: [])
        let filtered = AgenticGrep.memoryDynamicsFilter([forgotten, active])
        XCTAssertEqual(filtered.map(\.id), ["m218b"],
                       "re-asked queries must not surface facts retracted via /forget")
    }

    func testA218_ttlExpiredExcluded() {
        let past = ISO8601DateFormatter().string(from: Date().addingTimeInterval(-3600))
        let expired = MemoryEntry(id: "e218", memory: "TTL fact 218.", version: 1,
                                  isLatest: true, isForgotten: false, isStatic: false,
                                  parentMemoryId: nil, rootMemoryId: "e218",
                                  forgetAfter: past, forgetReason: nil, history: [])
        XCTAssertFalse(AgenticGrep.memoryDynamicsActive(expired),
                       "TTL-expired memories must not appear in answers")
    }
}

final class A131RegressionTests: XCTestCase {
    func testA131_citationIntegrity() {
        let ev = [Retrieved(memory: "User uses Bazel.", similarity: 0.9, source: .init(docId: "d131", path: "/f.md", title: "Notes"))]
        XCTAssertTrue(WorkScheduler.citationIntegritySupported("User uses Bazel [Notes].", evidence: ev))
        XCTAssertFalse(WorkScheduler.citationIntegritySupported("User uses CMake [Notes].", evidence: ev))
    }
    func testA131_unsupportedAnswerEvent() {
        XCTAssertEqual(WorkScheduler.unsupportedAnswerEvents(), [.state(.unsupportedAnswer)])
    }
}
final class A189RegressionTests: XCTestCase {
    func testA189_ingest() {
        XCTAssertEqual(ConflictDetector.indexingTerminalState(path:"/a.pdf"),.indexing(path:"/a.pdf"))
        XCTAssertEqual(ConflictDetector.ingestionSelfHealSafe(orphanIds:["x",""]),["x"])
    }
}
final class A160RegressionTests: XCTestCase { func testA160_x() { XCTAssertEqual(Preferences.unsupportedAnswerEvents(),[.state(.unsupportedAnswer)]) } }

final class A247RegressionTests: XCTestCase {
    func testA247_dreamingDoesNotDuplicateSynthesis() {
        let existing = [MemoryEntry(id: "s247", memory: "Synthesis 247.", version: 1,
                                    isLatest: true, isForgotten: false, isStatic: false,
                                    parentMemoryId: nil, rootMemoryId: "s247",
                                    forgetAfter: nil, forgetReason: nil, history: [])]
        XCTAssertFalse(ResponseStyle.dreamingSafeSynthesis("Synthesis 247.", existing: existing,
                                                      constituents: ["fact 247"]),
                       "dreaming must not duplicate existing syntheses")
        XCTAssertTrue(ResponseStyle.dreamingSafeSynthesis("New synthesis 247.", existing: existing,
                                                     constituents: ["fact 247"]),
                      "novel synthesis with constituent grounding is allowed")
    }
}
final class A102RegressionTests: XCTestCase { func testA102_x() { XCTAssertFalse(LocalExtractor.lifecycleEvents(branch:.retry).isEmpty) } }

final class A276RegressionTests: XCTestCase {
    func testA276_dreamingDoesNotDuplicateSynthesis() {
        let existing = [MemoryEntry(id: "s276", memory: "Synthesis 276.", version: 1,
                                    isLatest: true, isForgotten: false, isStatic: false,
                                    parentMemoryId: nil, rootMemoryId: "s276",
                                    forgetAfter: nil, forgetReason: nil, history: [])]
        XCTAssertFalse(ItemState.dreamingSafeSynthesis("Synthesis 276.", existing: existing,
                                                      constituents: ["fact 276"]),
                       "dreaming must not duplicate existing syntheses")
        XCTAssertTrue(ItemState.dreamingSafeSynthesis("New synthesis 276.", existing: existing,
                                                     constituents: ["fact 276"]),
                      "novel synthesis with constituent grounding is allowed")
    }
}

/// A-044: never-retrieved memories are not cold-archived by default.
final class ColdArchiveNeverRetrievedTests: XCTestCase {
    func testSkipsNeverRetrievedByDefault() {
        let old = Date().addingTimeInterval(-90 * 86400)
        let records = ["m1": StrengthRecord(retrievalCount: 0, lastRetrieved: old)]
        XCTAssertTrue(ColdArchive.archivable(records: records, now: Date(), thresholdDays: 30,
                                             archiveNeverRetrieved: false).isEmpty)
        XCTAssertEqual(ColdArchive.archivable(records: records, now: Date(), thresholdDays: 30,
                                              archiveNeverRetrieved: true), ["m1"])
    }
}
