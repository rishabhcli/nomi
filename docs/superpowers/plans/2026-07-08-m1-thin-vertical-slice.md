# M1 — Thin Vertical Slice (ask → cited answer) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Drop a text file into the memory-path, summon the notch surface, type a question, and get a **streamed, cited answer** rendered below the notch — with the network off.

**Architecture:** A `MnemoOrchestrator` library holds the query lifecycle (engine search client, Ollama streaming client, prompt/context builder, `QueryService` emitting `QueryEvent`s) — all unit-tested with fakes/stubs. A `MnemoApp` SwiftUI executable hosts a non-activating notch `NSPanel` whose view-model consumes `QueryService` events. UI rendering is verified manually; all logic is TDD.

**Tech Stack:** Swift 6, SwiftPM, XCTest, SwiftUI + AppKit (`NSPanel`, `NSScreen`), `URLSession` (HTTP + streaming bytes). Builds on **M0** (`MnemoConfig`, invariant). No Liquid Glass / voice yet (those are M12).

## Global Constraints

- **The invariant:** answer path/memory/model all local; loopback only; local model only. Engine `http://127.0.0.1:6767`, Ollama `http://127.0.0.1:11434` — read from `MnemoConfig` (M0), never hardcoded. (From [PLAN.md → M1](../../../PLAN.md#m1--thin-vertical-slice-ask--cited-answer).)
- **Generation contract:** answer ONLY from provided context; attach the source document to claims; state plainly when the corpus lacks the answer — never invent. (From [PLAN.md → M4](../../../PLAN.md#m4--query-lifecycle--routing).)
- **Deployment target macOS 26.0.**
- **Event order:** `route` → `sources` → `token…` → `done`; `sources` must precede the first `token` (pipelining).
- **Tests run network-off** (fakes/stubs only). The end-to-end acceptance runs against the real stack, network physically off.

---

### Task 1: Add orchestrator + app targets

**Files:**
- Modify: `Package.swift`
- Create: `Sources/MnemoOrchestrator/Placeholder.swift`
- Create: `Sources/MnemoApp/main.swift` (temporary)
- Create: `Tests/MnemoOrchestratorTests/Placeholder.swift`

**Interfaces:**
- Consumes: `MnemoCore` (M0).
- Produces: library target `MnemoOrchestrator`; executable `MnemoApp`; test target `MnemoOrchestratorTests`.

- [ ] **Step 1: Update `Package.swift`** — add to `products` and `targets`:

```swift
        .library(name: "MnemoOrchestrator", targets: ["MnemoOrchestrator"]),
        .executable(name: "MnemoApp", targets: ["MnemoApp"]),
```
```swift
        .target(name: "MnemoOrchestrator", dependencies: ["MnemoCore"]),
        .executableTarget(name: "MnemoApp", dependencies: ["MnemoOrchestrator"]),
        .testTarget(name: "MnemoOrchestratorTests", dependencies: ["MnemoOrchestrator"]),
```

- [ ] **Step 2: Placeholders** — `Sources/MnemoOrchestrator/Placeholder.swift`: `public enum MnemoOrchestratorModule {}`. `Sources/MnemoApp/main.swift`: `print("MnemoApp")`. `Tests/MnemoOrchestratorTests/Placeholder.swift`: `import XCTest; final class P: XCTestCase { func testNoop() {} }`.

- [ ] **Step 3: Build** — Run: `swift build` → Expected: success.

- [ ] **Step 4: Commit** — `git add -A && git commit -m "chore: add orchestrator + app targets (M1)"`

---

### Task 2: Retrieval types + engine search client

**Files:**
- Create: `Sources/MnemoOrchestrator/Retrieval.swift`
- Create: `Sources/MnemoOrchestrator/EngineClient.swift`
- Test: `Tests/MnemoOrchestratorTests/EngineClientTests.swift`
- Create: `Tests/MnemoOrchestratorTests/StubURLProtocol.swift` (copy from M0 Task 6)

**Interfaces:**
- Consumes: `MnemoConfig` (M0).
- Produces: `struct SourceLocator { docId, path, title: String; charStart, charEnd: Int }`; `struct Retrieved { memory: String; similarity: Double; source: SourceLocator }`; `struct SearchRequest { q; mode; rerank; threshold; limit; container? }`; `protocol Retrieving: Sendable { func search(_ req: SearchRequest) async throws -> [Retrieved] }`; `struct EngineClient: Retrieving` (`init(baseURL:session:)`).

- [ ] **Step 1: Write the failing test**

`Tests/MnemoOrchestratorTests/EngineClientTests.swift`:
```swift
import XCTest
@testable import MnemoOrchestrator

final class EngineClientTests: XCTestCase {
    func testDecodesSearchResults() async throws {
        StubURLProtocol.handler = { req in
            XCTAssertEqual(req.url?.path, "/v4/search")
            let json = """
            {"results":[{"memory":"I moved to SF.","similarity":0.82,
              "source":{"doc_id":"sha256:x","path":"/m/f.md","title":"f","char_start":10,"char_end":25}}]}
            """
            return (HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, Data(json.utf8))
        }
        let cfg = URLSessionConfiguration.ephemeral; cfg.protocolClasses = [StubURLProtocol.self]
        let client = EngineClient(baseURL: URL(string: "http://127.0.0.1:6767")!, session: URLSession(configuration: cfg))
        let out = try await client.search(SearchRequest(q: "where do I live?"))
        XCTAssertEqual(out.count, 1)
        XCTAssertEqual(out[0].memory, "I moved to SF.")
        XCTAssertEqual(out[0].source.charStart, 10)
        XCTAssertEqual(out[0].source.title, "f")
    }
}
```
(Copy `StubURLProtocol` verbatim from M0 Task 6 into `Tests/MnemoOrchestratorTests/StubURLProtocol.swift`.)

- [ ] **Step 2: Run to verify fail** — `swift test --filter EngineClientTests` → FAIL.

- [ ] **Step 3: Implement**

`Sources/MnemoOrchestrator/Retrieval.swift`:
```swift
import Foundation

public struct SourceLocator: Equatable, Sendable, Codable {
    public let docId: String, path: String, title: String
    public let charStart: Int, charEnd: Int
    enum CodingKeys: String, CodingKey {
        case docId = "doc_id", path, title, charStart = "char_start", charEnd = "char_end"
    }
}
public struct Retrieved: Equatable, Sendable, Codable {
    public let memory: String
    public let similarity: Double
    public let source: SourceLocator
}
public struct SearchRequest: Sendable {
    public var q: String
    public var mode: String = "memories"   // "memories" | "hybrid"
    public var rerank: Bool = true
    public var threshold: Double = 0.35
    public var limit: Int = 12
    public var container: String? = nil
    public init(q: String) { self.q = q }
}
public protocol Retrieving: Sendable {
    func search(_ req: SearchRequest) async throws -> [Retrieved]
}
```

`Sources/MnemoOrchestrator/EngineClient.swift`:
```swift
import Foundation

public struct EngineClient: Retrieving {
    let baseURL: URL
    let session: URLSession
    public init(baseURL: URL, session: URLSession = .shared) { self.baseURL = baseURL; self.session = session }

    struct Wire: Encodable { let q: String; let mode: String; let rerank: Bool; let threshold: Double; let limit: Int; let container: String? }
    struct Response: Decodable { let results: [Retrieved] }

    public func search(_ req: SearchRequest) async throws -> [Retrieved] {
        var url = baseURL; url.append(path: "/v4/search")
        var r = URLRequest(url: url); r.httpMethod = "POST"
        r.setValue("application/json", forHTTPHeaderField: "Content-Type")
        r.httpBody = try JSONEncoder().encode(Wire(q: req.q, mode: req.mode, rerank: req.rerank, threshold: req.threshold, limit: req.limit, container: req.container))
        let (data, _) = try await session.data(for: r)
        return try JSONDecoder().decode(Response.self, from: data).results
    }
}
```

- [ ] **Step 4: Run to verify pass** — `swift test --filter EngineClientTests` → PASS.

- [ ] **Step 5: Commit** — `git add -A && git commit -m "feat(orch): retrieval types + /v4/search engine client"`

---

### Task 3: Ollama streaming client

**Files:**
- Create: `Sources/MnemoOrchestrator/OllamaClient.swift`
- Test: `Tests/MnemoOrchestratorTests/OllamaLineTests.swift`

**Interfaces:**
- Produces: `enum OllamaLine { static func parse(_ line: String) -> String? }` (returns the `response` token, or nil for done/empty); `protocol Generating: Sendable { func stream(system: String, prompt: String) -> AsyncThrowingStream<String, Error> }`; `struct OllamaClient: Generating` (`init(baseURL:model:session:)`).

- [ ] **Step 1: Write the failing test** (pure parser — hermetic):

```swift
import XCTest
@testable import MnemoOrchestrator

final class OllamaLineTests: XCTestCase {
    func testParsesResponseToken() {
        XCTAssertEqual(OllamaLine.parse(#"{"response":"Hello","done":false}"#), "Hello")
    }
    func testDoneLineYieldsNil() {
        XCTAssertNil(OllamaLine.parse(#"{"response":"","done":true}"#))
        XCTAssertNil(OllamaLine.parse(""))
    }
}
```

- [ ] **Step 2: Run to verify fail** — `swift test --filter OllamaLineTests` → FAIL.

- [ ] **Step 3: Implement** `Sources/MnemoOrchestrator/OllamaClient.swift`:

```swift
import Foundation

public enum OllamaLine {
    struct Chunk: Decodable { let response: String?; let done: Bool? }
    /// Returns the token in a streamed JSON line, or nil for empty/done lines.
    public static func parse(_ line: String) -> String? {
        let t = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty, let data = t.data(using: .utf8),
              let c = try? JSONDecoder().decode(Chunk.self, from: data),
              let r = c.response, !r.isEmpty else { return nil }
        return r
    }
}

public protocol Generating: Sendable {
    func stream(system: String, prompt: String) -> AsyncThrowingStream<String, Error>
}

public struct OllamaClient: Generating {
    let baseURL: URL, model: String, session: URLSession
    public init(baseURL: URL, model: String, session: URLSession = .shared) {
        self.baseURL = baseURL; self.model = model; self.session = session
    }
    struct Body: Encodable { let model: String; let system: String; let prompt: String; let stream = true }

    public func stream(system: String, prompt: String) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    var url = baseURL; url.append(path: "/api/generate")
                    var r = URLRequest(url: url); r.httpMethod = "POST"
                    r.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    r.httpBody = try JSONEncoder().encode(Body(model: model, system: system, prompt: prompt))
                    let (bytes, _) = try await session.bytes(for: r)
                    for try await line in bytes.lines {
                        if let tok = OllamaLine.parse(line) { continuation.yield(tok) }
                    }
                    continuation.finish()
                } catch { continuation.finish(throwing: error) }
            }
        }
    }
}
```

- [ ] **Step 4: Run to verify pass** — `swift test --filter OllamaLineTests` → PASS.

- [ ] **Step 5: Commit** — `git add -A && git commit -m "feat(orch): Ollama streaming client + line parser"`

---

### Task 4: Prompt + context assembly

**Files:**
- Create: `Sources/MnemoOrchestrator/Prompt.swift`
- Test: `Tests/MnemoOrchestratorTests/PromptTests.swift`

**Interfaces:**
- Consumes: `Retrieved` (Task 2).
- Produces: `enum Prompt { static let system: String; static func context(_ hits: [Retrieved]) -> String }`.

- [ ] **Step 1: Write the failing test**

```swift
import XCTest
@testable import MnemoOrchestrator

final class PromptTests: XCTestCase {
    func testSystemStatesContract() {
        XCTAssertTrue(Prompt.system.contains("only from the provided context"))
        XCTAssertTrue(Prompt.system.lowercased().contains("do not"))
    }
    func testContextTagsEachSpanWithSource() {
        let hit = Retrieved(memory: "I moved to SF.", similarity: 0.8,
            source: .init(docId: "d1", path: "/m/f.md", title: "f", charStart: 0, charEnd: 5))
        let ctx = Prompt.context([hit])
        XCTAssertTrue(ctx.contains("I moved to SF."))
        XCTAssertTrue(ctx.contains("f"))          // title
        XCTAssertTrue(ctx.contains("/m/f.md"))    // path
    }
    func testEmptyContextIsExplicit() {
        XCTAssertTrue(Prompt.context([]).contains("NO CONTEXT"))
    }
}
```

- [ ] **Step 2: Run to verify fail** — `swift test --filter PromptTests` → FAIL.

- [ ] **Step 3: Implement** `Sources/MnemoOrchestrator/Prompt.swift`:

```swift
public enum Prompt {
    public static let system = """
    You are Mnemo, an on-device assistant. Answer only from the provided context. \
    Attach the source document title to each claim. If the context does not contain \
    the answer, say so plainly — do not invent facts. Keep answers short; add structure \
    only when the answer is genuinely multi-part.
    """
    public static func context(_ hits: [Retrieved]) -> String {
        guard !hits.isEmpty else { return "NO CONTEXT AVAILABLE." }
        return hits.map { h in
            "[source: \(h.source.title) — \(h.source.path) @\(h.source.charStart)-\(h.source.charEnd)]\n\(h.memory)"
        }.joined(separator: "\n\n")
    }
}
```

- [ ] **Step 4: Run to verify pass** — `swift test --filter PromptTests` → PASS (3 tests).

- [ ] **Step 5: Commit** — `git add -A && git commit -m "feat(orch): generation contract + context assembly"`

---

### Task 5: QueryService (event lifecycle)

**Files:**
- Create: `Sources/MnemoOrchestrator/QueryService.swift`
- Test: `Tests/MnemoOrchestratorTests/QueryServiceTests.swift`

**Interfaces:**
- Consumes: `Retrieving`, `Generating`, `Prompt`, `Retrieved`.
- Produces: `struct SourceCard: Equatable, Sendable { let title, path, docId: String }`; `enum QueryEvent: Equatable, Sendable { case route(String); case sources([SourceCard]); case token(String); case done }`; `protocol QueryServing: Sendable { func ask(_ q: String) -> AsyncThrowingStream<QueryEvent, Error> }`; `struct QueryService: QueryServing` (`init(retriever:generator:)`).

- [ ] **Step 1: Write the failing test** (fakes; asserts `sources` precedes first `token`, and the not-in-corpus path):

```swift
import XCTest
@testable import MnemoOrchestrator

struct FakeRetriever: Retrieving {
    let hits: [Retrieved]
    func search(_ req: SearchRequest) async throws -> [Retrieved] { hits }
}
struct FakeGenerator: Generating {
    let tokens: [String]
    func stream(system: String, prompt: String) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { c in for t in tokens { c.yield(t) }; c.finish() }
    }
}
private let hit = Retrieved(memory: "I moved to SF.", similarity: 0.8,
    source: .init(docId: "d1", path: "/m/f.md", title: "f", charStart: 0, charEnd: 5))

final class QueryServiceTests: XCTestCase {
    func testEmitsSourcesBeforeTokensThenDone() async throws {
        let svc = QueryService(retriever: FakeRetriever(hits: [hit]), generator: FakeGenerator(tokens: ["A", "B"]))
        var events: [QueryEvent] = []
        for try await e in svc.ask("where do I live?") { events.append(e) }
        // route first
        XCTAssertEqual(events.first, .route("synthesis"))
        // sources before any token
        let sIdx = events.firstIndex(of: .sources([SourceCard(title: "f", path: "/m/f.md", docId: "d1")]))!
        let tIdx = events.firstIndex(of: .token("A"))!
        XCTAssertLessThan(sIdx, tIdx)
        XCTAssertEqual(events.last, .done)
    }
    func testNotInCorpusDoesNotInvent() async throws {
        let svc = QueryService(retriever: FakeRetriever(hits: []), generator: FakeGenerator(tokens: ["SHOULD_NOT_APPEAR"]))
        var text = ""
        for try await e in svc.ask("unknown") { if case let .token(t) = e { text += t } }
        XCTAssertFalse(text.contains("SHOULD_NOT_APPEAR"))
        XCTAssertTrue(text.lowercased().contains("don't") || text.lowercased().contains("not"))
    }
}
```

- [ ] **Step 2: Run to verify fail** — `swift test --filter QueryServiceTests` → FAIL.

- [ ] **Step 3: Implement** `Sources/MnemoOrchestrator/QueryService.swift`:

```swift
import Foundation

public struct SourceCard: Equatable, Sendable { public let title, path, docId: String }

public enum QueryEvent: Equatable, Sendable {
    case route(String)          // intent id — M1 is always "synthesis"
    case sources([SourceCard])
    case token(String)
    case done
}

public protocol QueryServing: Sendable {
    func ask(_ q: String) -> AsyncThrowingStream<QueryEvent, Error>
}

public struct QueryService: QueryServing {
    let retriever: Retrieving
    let generator: Generating
    public init(retriever: Retrieving, generator: Generating) {
        self.retriever = retriever; self.generator = generator
    }

    public func ask(_ q: String) -> AsyncThrowingStream<QueryEvent, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    continuation.yield(.route("synthesis"))          // M1: single-shot only
                    let hits = try await retriever.search(SearchRequest(q: q))
                    let cards = hits.map { SourceCard(title: $0.source.title, path: $0.source.path, docId: $0.source.docId) }
                    // dedupe by docId, preserve order
                    var seen = Set<String>(); let uniq = cards.filter { seen.insert($0.docId).inserted }
                    continuation.yield(.sources(uniq))               // sub-second, before tokens
                    if hits.isEmpty {
                        continuation.yield(.token("I don't have anything in your files about that."))
                        continuation.yield(.done); continuation.finish(); return
                    }
                    for try await tok in generator.stream(system: Prompt.system, prompt: "\(Prompt.context(hits))\n\nQuestion: \(q)") {
                        continuation.yield(.token(tok))
                    }
                    continuation.yield(.done); continuation.finish()
                } catch { continuation.finish(throwing: error) }
            }
        }
    }
}
```

- [ ] **Step 4: Run to verify pass** — `swift test --filter QueryServiceTests` → PASS (2 tests).

- [ ] **Step 5: Commit** — `git add -A && git commit -m "feat(orch): QueryService event lifecycle (route→sources→tokens→done)"`

---

### Task 6: Ingest gate (write file + wait until searchable)

**Files:**
- Create: `Sources/MnemoOrchestrator/IngestGate.swift`
- Test: `Tests/MnemoOrchestratorTests/IngestGateTests.swift`

**Interfaces:**
- Consumes: `Retrieving`.
- Produces: `struct IngestGate` with `init(retriever:)` and `func waitUntilSearchable(probe query: String, timeout: Duration) async -> Bool` (polls search until non-empty). File writing is a thin `writeFile(_:to:)` helper. (Full item-state machine is M2; M1 just needs "is it searchable yet".)

- [ ] **Step 1: Write the failing test**

```swift
import XCTest
@testable import MnemoOrchestrator

final class IngestGateTests: XCTestCase {
    actor Counter { var n = 0; func next() -> Int { n += 1; return n } }
    struct EventuallyReady: Retrieving {
        let counter: IngestGateTests.Counter
        let hit: Retrieved
        func search(_ req: SearchRequest) async throws -> [Retrieved] {
            (await counter.next()) >= 3 ? [hit] : []   // empty twice, then ready
        }
    }
    func testWaitsUntilSearchable() async {
        let hit = Retrieved(memory: "x", similarity: 0.9, source: .init(docId: "d", path: "/p", title: "t", charStart: 0, charEnd: 1))
        let gate = IngestGate(retriever: EventuallyReady(counter: Counter(), hit: hit))
        let ok = await gate.waitUntilSearchable(probe: "x", timeout: .seconds(5))
        XCTAssertTrue(ok)
    }
    func testTimesOutWhenNeverReady() async {
        struct NeverReady: Retrieving { func search(_ r: SearchRequest) async throws -> [Retrieved] { [] } }
        let gate = IngestGate(retriever: NeverReady())
        let ok = await gate.waitUntilSearchable(probe: "x", timeout: .milliseconds(400))
        XCTAssertFalse(ok)
    }
}
```

- [ ] **Step 2: Run to verify fail** — `swift test --filter IngestGateTests` → FAIL.

- [ ] **Step 3: Implement** `Sources/MnemoOrchestrator/IngestGate.swift`:

```swift
import Foundation

public struct IngestGate {
    let retriever: Retrieving
    public init(retriever: Retrieving) { self.retriever = retriever }

    public func writeFile(_ contents: String, to url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try contents.write(to: url, atomically: true, encoding: .utf8)
    }

    /// Polls search until the probe query returns any result, or the timeout elapses.
    public func waitUntilSearchable(probe query: String, timeout: Duration) async -> Bool {
        let deadline = ContinuousClock.now.advanced(by: timeout)
        while ContinuousClock.now < deadline {
            if let hits = try? await retriever.search(SearchRequest(q: query)), !hits.isEmpty { return true }
            try? await Task.sleep(for: .milliseconds(200))
        }
        return false
    }
}
```

- [ ] **Step 4: Run to verify pass** — `swift test --filter IngestGateTests` → PASS (2 tests).

- [ ] **Step 5: Commit** — `git add -A && git commit -m "feat(orch): ingest gate (write + wait-until-searchable)"`

---

### Task 7: Notch geometry

**Files:**
- Create: `Sources/MnemoApp/NotchGeometry.swift`
- Test: `Tests/MnemoOrchestratorTests/NotchGeometryTests.swift` (move geometry math into `MnemoOrchestrator` so it's testable, and re-export from the app)

**Interfaces:**
- Produces: pure `enum NotchGeometry { static func rect(screenFrame: CGRect, safeAreaTop: CGFloat, auxLeftWidth: CGFloat, auxRightWidth: CGFloat) -> CGRect?; static func hasNotch(safeAreaTop: CGFloat, auxLeftWidth: CGFloat, auxRightWidth: CGFloat) -> Bool }`. (Put this in `MnemoOrchestrator` for tests; the `NSScreen` extension in the app calls it.)

- [ ] **Step 1: Write the failing test** — create `Tests/MnemoOrchestratorTests/NotchGeometryTests.swift`:

```swift
import XCTest
import CoreGraphics
@testable import MnemoOrchestrator

final class NotchGeometryTests: XCTestCase {
    func testComputesCenteredNotchRect() {
        // 1512-wide screen, notch height 38, aux areas 656 each → notch width 200, centered
        let screen = CGRect(x: 0, y: 0, width: 1512, height: 982)
        let r = NotchGeometry.rect(screenFrame: screen, safeAreaTop: 38, auxLeftWidth: 656, auxRightWidth: 656)!
        XCTAssertEqual(r.width, 200, accuracy: 0.5)
        XCTAssertEqual(r.height, 38, accuracy: 0.5)
        XCTAssertEqual(r.midX, screen.midX, accuracy: 0.5)
        XCTAssertEqual(r.maxY, screen.maxY, accuracy: 0.5)   // pinned to top
    }
    func testNoNotchWhenSafeAreaZero() {
        XCTAssertFalse(NotchGeometry.hasNotch(safeAreaTop: 0, auxLeftWidth: 0, auxRightWidth: 0))
        XCTAssertNil(NotchGeometry.rect(screenFrame: .init(x:0,y:0,width:1440,height:900), safeAreaTop: 0, auxLeftWidth: 0, auxRightWidth: 0))
    }
}
```

- [ ] **Step 2: Run to verify fail** — `swift test --filter NotchGeometryTests` → FAIL.

- [ ] **Step 3: Implement** `Sources/MnemoOrchestrator/NotchGeometry.swift` (note: in the Orchestrator target so it's testable):

```swift
import CoreGraphics

public enum NotchGeometry {
    public static func hasNotch(safeAreaTop: CGFloat, auxLeftWidth: CGFloat, auxRightWidth: CGFloat) -> Bool {
        safeAreaTop > 0 && auxLeftWidth > 0 && auxRightWidth > 0
    }
    public static func rect(screenFrame: CGRect, safeAreaTop: CGFloat, auxLeftWidth: CGFloat, auxRightWidth: CGFloat) -> CGRect? {
        guard hasNotch(safeAreaTop: safeAreaTop, auxLeftWidth: auxLeftWidth, auxRightWidth: auxRightWidth) else { return nil }
        let width = screenFrame.width - auxLeftWidth - auxRightWidth
        return CGRect(x: screenFrame.midX - width/2, y: screenFrame.maxY - safeAreaTop, width: width, height: safeAreaTop)
    }
}
```

- [ ] **Step 4: Add the `NSScreen` bridge** `Sources/MnemoApp/NotchGeometry.swift`:

```swift
import AppKit
import MnemoOrchestrator

extension NSScreen {
    var mnemoNotchRect: CGRect? {
        NotchGeometry.rect(screenFrame: frame, safeAreaTop: safeAreaInsets.top,
                           auxLeftWidth: auxiliaryTopLeftArea?.width ?? 0,
                           auxRightWidth: auxiliaryTopRightArea?.width ?? 0)
    }
    /// Virtual notch for no-notch displays (200×32 pill at top-center). Full spec: UI.md §2.
    var mnemoNotchRectOrVirtual: CGRect {
        mnemoNotchRect ?? CGRect(x: frame.midX - 100, y: frame.maxY - 32, width: 200, height: 32)
    }
}
```

- [ ] **Step 5: Run to verify pass + commit** — `swift test --filter NotchGeometryTests` → PASS (2 tests).
```bash
git add -A && git commit -m "feat(ui): notch geometry (testable) + NSScreen bridge + virtual notch"
```

---

### Task 8: Notch view-model

**Files:**
- Create: `Sources/MnemoApp/NotchViewModel.swift`
- Test: `Tests/MnemoOrchestratorTests/NotchViewModelLogicTests.swift`

**Interfaces:**
- Consumes: `QueryServing`, `QueryEvent`, `SourceCard`.
- Produces: `enum NotchPhase { case idle, input, searching, answering }`; `@MainActor final class NotchViewModel: ObservableObject` with `@Published phase`, `@Published query`, `@Published answer`, `@Published sources: [SourceCard]`, and `func submit() async` that consumes `QueryService.ask` and updates state. (Put the pure reducer `NotchReducer.apply(_ event:to:)` in `MnemoOrchestrator` for hermetic tests.)

- [ ] **Step 1: Write the failing test** (test the pure reducer):

```swift
import XCTest
@testable import MnemoOrchestrator

final class NotchViewModelLogicTests: XCTestCase {
    func testReducerBuildsAnswerAndSources() {
        var s = NotchState(phase: .searching, query: "q", answer: "", sources: [])
        s = NotchReducer.apply(.sources([SourceCard(title: "t", path: "/p", docId: "d")]), to: s)
        XCTAssertEqual(s.sources.count, 1)
        s = NotchReducer.apply(.token("Hel"), to: s)
        s = NotchReducer.apply(.token("lo"), to: s)
        XCTAssertEqual(s.phase, .answering)
        XCTAssertEqual(s.answer, "Hello")
        s = NotchReducer.apply(.done, to: s)
        XCTAssertEqual(s.phase, .answering)
    }
}
```

- [ ] **Step 2: Run to verify fail** — `swift test --filter NotchViewModelLogicTests` → FAIL.

- [ ] **Step 3: Implement the reducer** `Sources/MnemoOrchestrator/NotchReducer.swift`:

```swift
public enum NotchPhase: Equatable, Sendable { case idle, input, searching, answering }

public struct NotchState: Equatable, Sendable {
    public var phase: NotchPhase
    public var query: String
    public var answer: String
    public var sources: [SourceCard]
    public init(phase: NotchPhase, query: String, answer: String, sources: [SourceCard]) {
        self.phase = phase; self.query = query; self.answer = answer; self.sources = sources
    }
}

public enum NotchReducer {
    public static func apply(_ event: QueryEvent, to s: NotchState) -> NotchState {
        var s = s
        switch event {
        case .route: s.phase = .searching
        case .sources(let cards): s.sources = cards
        case .token(let t): s.phase = .answering; s.answer += t
        case .done: break
        }
        return s
    }
}
```

- [ ] **Step 4: Implement the view-model** `Sources/MnemoApp/NotchViewModel.swift`:

```swift
import SwiftUI
import MnemoOrchestrator

@MainActor
final class NotchViewModel: ObservableObject {
    @Published var state = NotchState(phase: .idle, query: "", answer: "", sources: [])
    private let service: QueryServing
    init(service: QueryServing) { self.service = service }

    func summon() { state = NotchState(phase: .input, query: "", answer: "", sources: []) }
    func dismiss() { state.phase = .idle }

    func submit() async {
        guard !state.query.isEmpty else { return }
        state.answer = ""; state.sources = []; state.phase = .searching
        do { for try await e in service.ask(state.query) { state = NotchReducer.apply(e, to: state) } }
        catch { state.answer = "Something went wrong. Please try again." }
    }
}
```

- [ ] **Step 5: Run to verify pass + commit** — `swift test --filter NotchViewModelLogicTests` → PASS.
```bash
git add -A && git commit -m "feat(ui): notch reducer (tested) + view-model"
```

---

### Task 9: Notch panel + minimal SwiftUI surface

**Files:**
- Create: `Sources/MnemoApp/NotchPanel.swift`
- Create: `Sources/MnemoApp/NotchSurfaceView.swift`
- Create: `Sources/MnemoApp/NotchController.swift`
- Rewrite: `Sources/MnemoApp/main.swift` (real `@main` app)

**Interfaces:**
- Consumes: `NotchViewModel`, `NSScreen.mnemoNotchRectOrVirtual`, `EngineClient`, `OllamaClient`, `QueryService`, `MnemoConfig`.
- Produces: the running app: hover/menubar summon → input → streamed cited answer below the notch. (Liquid Glass, blur-morph, voice: deferred to M12.)

> AppKit/SwiftUI rendering is verified manually (Step 5). Logic already tested in Tasks 7–8.

- [ ] **Step 1: `NotchPanel`** `Sources/MnemoApp/NotchPanel.swift`:

```swift
import AppKit

final class NotchPanel: NSPanel {
    init(contentRect: NSRect) {
        super.init(contentRect: contentRect, styleMask: [.nonactivatingPanel, .borderless],
                   backing: .buffered, defer: false)
        isFloatingPanel = true
        level = .statusBar          // M12 refines to .statusBar+8 with NotchShape
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        backgroundColor = .clear
        isOpaque = false
        hasShadow = true
        hidesOnDeactivate = false
    }
    override var canBecomeKey: Bool { true }   // so the input takes the keyboard immediately
}
```

- [ ] **Step 2: `NotchSurfaceView`** `Sources/MnemoApp/NotchSurfaceView.swift`:

```swift
import SwiftUI
import MnemoOrchestrator

struct NotchSurfaceView: View {
    @ObservedObject var vm: NotchViewModel
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            TextField("Ask Mnemo", text: $vm.state.query)
                .textFieldStyle(.plain).font(.system(size: 15))
                .focused($focused)
                .onSubmit { Task { await vm.submit() } }
            if vm.state.phase == .searching { ProgressView().controlSize(.small) }
            if !vm.state.answer.isEmpty {
                Text(vm.state.answer).font(.system(size: 15)).foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)
            }
            ForEach(vm.state.sources, id: \.docId) { card in
                Button { revealInFinder(card.path) } label: {
                    Label(card.title, systemImage: "doc.text").font(.system(size: 12))
                }.buttonStyle(.plain).foregroundStyle(.secondary)
            }
        }
        .padding(16).frame(width: 460, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(.black.opacity(0.92)))
        .onAppear { focused = true }
    }
    func revealInFinder(_ path: String) {
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: (path as NSString).expandingTildeInPath)])
    }
}
```

- [ ] **Step 3: `NotchController`** `Sources/MnemoApp/NotchController.swift`:

```swift
import AppKit
import SwiftUI
import MnemoOrchestrator
import MnemoCore

@MainActor
final class NotchController {
    let panel: NotchPanel
    let vm: NotchViewModel

    init(config: MnemoConfig) {
        let engine = EngineClient(baseURL: config.engine.baseURL)
        let ollama = OllamaClient(baseURL: config.model.runtimeBaseURL, model: config.model.synthesis)
        self.vm = NotchViewModel(service: QueryService(retriever: engine, generator: ollama))
        let screen = NSScreen.main!
        let notch = screen.mnemoNotchRectOrVirtual
        // Panel hangs just below the notch, centered on it.
        let rect = NSRect(x: notch.midX - 250, y: notch.minY - 520, width: 500, height: 520)
        self.panel = NotchPanel(contentRect: rect)
        panel.contentView = NSHostingView(rootView: NotchSurfaceView(vm: vm))
    }
    func summon() { vm.summon(); panel.makeKeyAndOrderFront(nil) }
    func dismiss() { vm.dismiss(); panel.orderOut(nil) }
}
```

- [ ] **Step 4: `@main` app** — rewrite `Sources/MnemoApp/main.swift`:

```swift
import AppKit
import MnemoCore

let text = (try? String(contentsOfFile: "mnemo.toml", encoding: .utf8)) ?? ""
guard let config = try? MnemoConfig.load(from: text), (try? config.validateInvariant()) != nil else {
    FileHandle.standardError.write(Data("invalid mnemo.toml (invariant)\n".utf8)); exit(3)
}
let app = NSApplication.shared
app.setActivationPolicy(.accessory)   // no dock icon; system-surface feel
let delegate = AppDelegate(config: config)
app.delegate = delegate
app.run()

final class AppDelegate: NSObject, NSApplicationDelegate {
    let config: MnemoConfig
    var controller: NotchController!
    var statusItem: NSStatusItem!
    init(config: MnemoConfig) { self.config = config }
    func applicationDidFinishLaunching(_ n: Notification) {
        controller = NotchController(config: config)
        // M1 summon: menu-bar item (global hotkey + hover come in M12).
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.title = "◗"
        statusItem.button?.target = self
        statusItem.button?.action = #selector(toggle)
    }
    @objc func toggle() { controller.panel.isVisible ? controller.dismiss() : controller.summon() }
}
```

- [ ] **Step 5: Manual UI verification** — Run: `swift run MnemoApp` (with the M0 stack up, **network off**). Click the menu-bar `◗`. Expected: a dark rounded panel appears below the notch with a focused input; typing a question and pressing Return streams an answer with a source row; clicking the source row reveals the file in Finder. Fix layout until it matches. Commit:
```bash
git add -A && git commit -m "feat(ui): notch panel + minimal streamed-answer surface (M1 UI)"
```

---

### Task 10: End-to-end offline acceptance

**Files:**
- Create: `scripts/m1-acceptance.md` (manual acceptance script)
- Create: `Tests/Fixtures/fixture.md`

**Interfaces:** Consumes the whole M1 stack.

- [ ] **Step 1: Create the fixture** `Tests/Fixtures/fixture.md` with a known fact, e.g. `My favorite build tool is Bazel and I switched to it in March 2025.`

- [ ] **Step 2: Write the acceptance script** `scripts/m1-acceptance.md`:

```
# M1 acceptance (run with the M0 stack up, Wi-Fi OFF + Ethernet unplugged)
1. Copy Tests/Fixtures/fixture.md into the memory-path (~/Mnemo/memory/).
2. Wait until searchable (mnemoctl or just retry the query).
3. swift run MnemoApp ; click the menu-bar ◗.
4. Ask: "What's my favorite build tool?"  → AT-M1.1: answer streams containing "Bazel".
5. AT-M1.2: a source card for fixture.md appears; clicking reveals it in Finder.
6. Ask: "What's my dog's name?" (not in corpus) → AT-M1.3: says it doesn't have that; does NOT invent.
7. Observe AT-M1.4: the source card appears before the first answer token.
# BS-M1: repeat step 4 with ALL networking physically disabled → still answers.
```

- [ ] **Step 3: Run acceptance** — perform the steps. Expected: AT-M1.1–1.4 and BS-M1 all pass, network off.

- [ ] **Step 4: Record the proof** — screen-capture the offline cited answer to `Tests/Fixtures/demos/m1-offline.mov`.

- [ ] **Step 5: Commit** — `git add -A && git commit -m "test(m1): offline end-to-end acceptance + fixture + demo (M1 complete)"`

---

## M1 Definition of Done
- [ ] `swift test` green (Tasks 2–8), network-off.
- [ ] `swift run MnemoApp` → summon → streamed **cited** answer over `fixture.md`, network physically off (AT-M1.1, AT-M1.2).
- [ ] Out-of-corpus question is refused, not invented (AT-M1.3).
- [ ] `sources` event precedes first `token` (AT-M1.4 — asserted in `QueryServiceTests` + observed in UI).
- [ ] BS-M1 recorded to `Tests/Fixtures/demos/m1-offline.mov`.
- [ ] Interfaces `Retrieving`, `Generating`, `QueryServing`, `QueryEvent`, `SourceCard`, `NotchState/NotchReducer`, `NotchGeometry` are stable for M2+ to consume.
