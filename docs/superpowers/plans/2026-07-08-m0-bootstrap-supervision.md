# M0 — Bootstrap & Process Supervision Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Stand up a SwiftPM project that loads/validates config against the on-device invariant, models stack health, and supervises the four processes (Ollama, engine, SMFS) in dependency order — all testable network-off.

**Architecture:** Pure Swift library targets (`MnemoCore`, `MnemoSupervisor`) hold all logic and are fully unit-tested with `swift test`. Process launching and socket inspection sit behind protocols with fakes for tests; a thin `mnemoctl` executable and a launchd plist wire the real binaries. No UI in this milestone.

**Tech Stack:** Swift 6, SwiftPM, XCTest, Foundation (`URLSession`, `Process`), `lsof` for socket inspection.

## Global Constraints

- **The invariant:** answer path, memory, model all local. `engine.base_url`, `model.runtime_base_url`, `smfs.backing_store` MUST be loopback (`127.0.0.1`/`localhost`); `smfs.backing_store` MUST equal `engine.base_url`. Any violation aborts startup. (Copied from [PLAN.md → Appendix A](../../../PLAN.md#appendix-a--configuration-mnemotoml).)
- **Loopback only:** no process may bind anything but `127.0.0.1`.
- **Deployment target macOS 26.0** for the eventual app; M0 library targets set `platforms: [.macOS(.v26)]`.
- **Ports:** engine `127.0.0.1:6767`, Ollama `127.0.0.1:11434`.
- **Start order:** `ollama → engine → smfs`.
- **Tests run network-off.** All M0 tests use fakes/stubs; no test may hit a real network.

---

### Task 1: Project scaffold + git

**Files:**
- Create: `Package.swift`
- Create: `.gitignore`
- Create: `Sources/MnemoCore/Placeholder.swift`
- Create: `Tests/MnemoCoreTests/SmokeTests.swift`

**Interfaces:**
- Consumes: nothing.
- Produces: SwiftPM package `Mnemo` with library target `MnemoCore` and test target `MnemoCoreTests`; `swift build`/`swift test` work.

- [ ] **Step 1: Create `Package.swift`**

```swift
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Mnemo",
    platforms: [.macOS(.v26)],
    products: [
        .library(name: "MnemoCore", targets: ["MnemoCore"]),
        .library(name: "MnemoSupervisor", targets: ["MnemoSupervisor"]),
        .executable(name: "mnemoctl", targets: ["mnemoctl"]),
    ],
    targets: [
        .target(name: "MnemoCore"),
        .target(name: "MnemoSupervisor", dependencies: ["MnemoCore"]),
        .executableTarget(name: "mnemoctl", dependencies: ["MnemoSupervisor"]),
        .testTarget(name: "MnemoCoreTests", dependencies: ["MnemoCore"]),
        .testTarget(name: "MnemoSupervisorTests", dependencies: ["MnemoSupervisor"]),
    ]
)
```

- [ ] **Step 2: Create `.gitignore`**

```gitignore
.build/
.DS_Store
*.xcodeproj
*.xcworkspace
DerivedData/
```

- [ ] **Step 3: Create placeholder sources so the targets compile**

`Sources/MnemoCore/Placeholder.swift`:
```swift
// Intentionally minimal; real types arrive in later tasks.
public enum Mnemo { public static let version = "0.0.0" }
```

`Tests/MnemoCoreTests/SmokeTests.swift`:
```swift
import XCTest
@testable import MnemoCore

final class SmokeTests: XCTestCase {
    func testVersionExists() { XCTAssertEqual(Mnemo.version, "0.0.0") }
}
```

Also create empty `Sources/MnemoSupervisor/Placeholder.swift` (`public enum MnemoSupervisorModule {}`), `Sources/mnemoctl/main.swift` (`print("mnemoctl")`), and `Tests/MnemoSupervisorTests/Placeholder.swift` (`import XCTest\nfinal class P: XCTestCase { func testNoop() {} }`).

- [ ] **Step 4: Build and test**

Run: `swift build && swift test`
Expected: build succeeds; `1 test` (plus the noop) passes.

- [ ] **Step 5: Commit**

```bash
git init && git add -A && git commit -m "chore: scaffold Mnemo SwiftPM package (M0)"
```

---

### Task 2: Minimal TOML parser

**Files:**
- Create: `Sources/MnemoCore/TOML.swift`
- Test: `Tests/MnemoCoreTests/TOMLTests.swift`

**Interfaces:**
- Consumes: nothing.
- Produces: `TOMLValue` enum (`.string/.int/.double/.bool`); `TOML.parse(_ text: String) throws -> [String: [String: TOMLValue]]` (outer key = section name, `""` for root).

- [ ] **Step 1: Write the failing test**

`Tests/MnemoCoreTests/TOMLTests.swift`:
```swift
import XCTest
@testable import MnemoCore

final class TOMLTests: XCTestCase {
    func testParsesSectionsAndScalars() throws {
        let text = """
        # comment
        root_key = "hi"

        [engine]
        base_url = "http://127.0.0.1:6767"
        rerank = true
        limit = 12
        threshold = 0.35
        """
        let t = try TOML.parse(text)
        XCTAssertEqual(t[""]?["root_key"], .string("hi"))
        XCTAssertEqual(t["engine"]?["base_url"], .string("http://127.0.0.1:6767"))
        XCTAssertEqual(t["engine"]?["rerank"], .bool(true))
        XCTAssertEqual(t["engine"]?["limit"], .int(12))
        XCTAssertEqual(t["engine"]?["threshold"], .double(0.35))
    }

    func testStripsInlineCommentsAndWhitespace() throws {
        let t = try TOML.parse("[x]\n a = \"v\"   # trailing\n")
        XCTAssertEqual(t["x"]?["a"], .string("v"))
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter TOMLTests`
Expected: FAIL — `TOML` not defined.

- [ ] **Step 3: Write minimal implementation**

`Sources/MnemoCore/TOML.swift`:
```swift
import Foundation

public enum TOMLValue: Equatable {
    case string(String), int(Int), double(Double), bool(Bool)
}

public enum TOMLError: Error, Equatable { case malformedLine(String) }

public enum TOML {
    public static func parse(_ text: String) throws -> [String: [String: TOMLValue]] {
        var out: [String: [String: TOMLValue]] = ["": [:]]
        var section = ""
        for raw in text.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = stripComment(String(raw)).trimmingCharacters(in: .whitespaces)
            if line.isEmpty { continue }
            if line.hasPrefix("[") && line.hasSuffix("]") {
                section = String(line.dropFirst().dropLast()).trimmingCharacters(in: .whitespaces)
                out[section, default: [:]] = out[section] ?? [:]
                continue
            }
            guard let eq = line.firstIndex(of: "=") else { throw TOMLError.malformedLine(line) }
            let key = String(line[..<eq]).trimmingCharacters(in: .whitespaces)
            let rhs = String(line[line.index(after: eq)...]).trimmingCharacters(in: .whitespaces)
            out[section, default: [:]][key] = try value(rhs)
        }
        return out
    }

    private static func stripComment(_ s: String) -> String {
        // strip # not inside quotes
        var inStr = false; var result = ""
        for ch in s {
            if ch == "\"" { inStr.toggle() }
            if ch == "#" && !inStr { break }
            result.append(ch)
        }
        return result
    }

    private static func value(_ s: String) throws -> TOMLValue {
        if s.hasPrefix("\"") && s.hasSuffix("\"") && s.count >= 2 {
            return .string(String(s.dropFirst().dropLast()))
        }
        if s == "true" { return .bool(true) }
        if s == "false" { return .bool(false) }
        if let i = Int(s) { return .int(i) }
        if let d = Double(s) { return .double(d) }
        throw TOMLError.malformedLine(s)
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --filter TOMLTests`
Expected: PASS (2 tests).

- [ ] **Step 5: Commit**

```bash
git add -A && git commit -m "feat(core): minimal TOML parser for mnemo.toml"
```

---

### Task 3: Config model + loader

**Files:**
- Create: `Sources/MnemoCore/MnemoConfig.swift`
- Create: `mnemo.toml` (repo root — the real default config)
- Test: `Tests/MnemoCoreTests/ConfigTests.swift`

**Interfaces:**
- Consumes: `TOML.parse` (Task 2).
- Produces: `struct MnemoConfig` with `engine/model/smfs/sync/retrieval` sub-structs; `MnemoConfig.load(from text: String) throws -> MnemoConfig`; `ConfigError` enum (`.missingKey(String)`, `.parse(String)`, plus invariant cases added in Task 4).

- [ ] **Step 1: Write the failing test**

`Tests/MnemoCoreTests/ConfigTests.swift`:
```swift
import XCTest
@testable import MnemoCore

final class ConfigTests: XCTestCase {
    static let sample = """
    [engine]
    base_url = "http://127.0.0.1:6767"
    byom = "ollama"
    embeddings = "local"
    [model]
    runtime_base_url = "http://127.0.0.1:11434"
    synthesis = "gpt-oss:20b"
    fallback = "qwen3:4b"
    keep_alive = "30m"
    [smfs]
    mount_point = "~/Mnemo/memory"
    backing_store = "http://127.0.0.1:6767"
    [sync]
    poll_seconds = 30
    [retrieval]
    default_mode = "memories"
    rerank = true
    threshold = 0.35
    limit = 12
    """

    func testLoadsAllFields() throws {
        let c = try MnemoConfig.load(from: Self.sample)
        XCTAssertEqual(c.engine.baseURL.absoluteString, "http://127.0.0.1:6767")
        XCTAssertEqual(c.model.synthesis, "gpt-oss:20b")
        XCTAssertEqual(c.smfs.backingStore.absoluteString, "http://127.0.0.1:6767")
        XCTAssertEqual(c.sync.pollSeconds, 30)
        XCTAssertEqual(c.retrieval.limit, 12)
        XCTAssertEqual(c.retrieval.threshold, 0.35, accuracy: 0.0001)
    }

    func testMissingKeyThrows() {
        XCTAssertThrowsError(try MnemoConfig.load(from: "[engine]\nbyom = \"ollama\"\n"))
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter ConfigTests`
Expected: FAIL — `MnemoConfig` not defined.

- [ ] **Step 3: Write minimal implementation**

`Sources/MnemoCore/MnemoConfig.swift`:
```swift
import Foundation

public enum ConfigError: Error, Equatable {
    case missingKey(String)
    case parse(String)
    case notLoopback(field: String, value: String)          // used in Task 4
    case backingStoreMismatch(backing: String, engine: String) // used in Task 4
}

public struct MnemoConfig: Equatable {
    public struct Engine: Equatable { public var baseURL: URL; public var byom: String; public var embeddings: String }
    public struct Model: Equatable { public var runtimeBaseURL: URL; public var synthesis: String; public var fallback: String; public var keepAlive: String }
    public struct SMFS: Equatable { public var mountPoint: String; public var backingStore: URL }
    public struct Sync: Equatable { public var pollSeconds: Int }
    public struct Retrieval: Equatable { public var defaultMode: String; public var rerank: Bool; public var threshold: Double; public var limit: Int }

    public var engine: Engine
    public var model: Model
    public var smfs: SMFS
    public var sync: Sync
    public var retrieval: Retrieval

    public static func load(from text: String) throws -> MnemoConfig {
        let t = try TOML.parse(text)
        func str(_ s: String, _ k: String) throws -> String {
            guard case let .string(v)? = t[s]?[k] else { throw ConfigError.missingKey("\(s).\(k)") }; return v
        }
        func url(_ s: String, _ k: String) throws -> URL {
            let v = try str(s, k); guard let u = URL(string: v) else { throw ConfigError.parse("\(s).\(k)") }; return u
        }
        func int(_ s: String, _ k: String) throws -> Int {
            guard case let .int(v)? = t[s]?[k] else { throw ConfigError.missingKey("\(s).\(k)") }; return v
        }
        func dbl(_ s: String, _ k: String) throws -> Double {
            if case let .double(v)? = t[s]?[k] { return v }
            if case let .int(v)? = t[s]?[k] { return Double(v) }
            throw ConfigError.missingKey("\(s).\(k)")
        }
        func bool(_ s: String, _ k: String) throws -> Bool {
            guard case let .bool(v)? = t[s]?[k] else { throw ConfigError.missingKey("\(s).\(k)") }; return v
        }
        return MnemoConfig(
            engine: .init(baseURL: try url("engine","base_url"), byom: try str("engine","byom"), embeddings: try str("engine","embeddings")),
            model: .init(runtimeBaseURL: try url("model","runtime_base_url"), synthesis: try str("model","synthesis"), fallback: try str("model","fallback"), keepAlive: try str("model","keep_alive")),
            smfs: .init(mountPoint: try str("smfs","mount_point"), backingStore: try url("smfs","backing_store")),
            sync: .init(pollSeconds: try int("sync","poll_seconds")),
            retrieval: .init(defaultMode: try str("retrieval","default_mode"), rerank: try bool("retrieval","rerank"), threshold: try dbl("retrieval","threshold"), limit: try int("retrieval","limit"))
        )
    }
}
```

- [ ] **Step 4: Create the real `mnemo.toml`** at repo root with the full config from [PLAN.md → Appendix A](../../../PLAN.md#appendix-a--configuration-mnemotoml) (engine/model/model.effort/smfs/sync/retrieval/agentic/dreaming/sla/ui/privacy sections). This file is the runtime source of config.

- [ ] **Step 5: Run test + commit**

Run: `swift test --filter ConfigTests` → Expected: PASS (2 tests).
```bash
git add -A && git commit -m "feat(core): MnemoConfig model + loader + default mnemo.toml"
```

---

### Task 4: Loopback invariant validation

**Files:**
- Modify: `Sources/MnemoCore/MnemoConfig.swift` (add `isLoopback`, `validateInvariant()`)
- Test: `Tests/MnemoCoreTests/InvariantTests.swift`

**Interfaces:**
- Consumes: `MnemoConfig` (Task 3), `ConfigError.notLoopback/.backingStoreMismatch` (already declared in Task 3).
- Produces: `func isLoopback(_ url: URL) -> Bool`; `MnemoConfig.validateInvariant() throws`.

- [ ] **Step 1: Write the failing test**

`Tests/MnemoCoreTests/InvariantTests.swift`:
```swift
import XCTest
@testable import MnemoCore

final class InvariantTests: XCTestCase {
    func testValidConfigPasses() throws {
        try MnemoConfig.load(from: ConfigTests.sample).validateInvariant()
    }
    func testNonLoopbackEngineRejected() throws {
        let bad = ConfigTests.sample.replacingOccurrences(
            of: "base_url = \"http://127.0.0.1:6767\"",
            with: "base_url = \"http://api.supermemory.ai\"")
        // NOTE: smfs.backing_store still 127.0.0.1 → also triggers mismatch; assert it throws notLoopback for engine first
        XCTAssertThrowsError(try MnemoConfig.load(from: bad).validateInvariant()) { err in
            XCTAssertEqual(err as? ConfigError, .notLoopback(field: "engine.base_url", value: "http://api.supermemory.ai"))
        }
    }
    func testBackingStoreMismatchRejected() throws {
        let bad = ConfigTests.sample.replacingOccurrences(
            of: "backing_store = \"http://127.0.0.1:6767\"",
            with: "backing_store = \"http://127.0.0.1:9999\"")
        XCTAssertThrowsError(try MnemoConfig.load(from: bad).validateInvariant()) { err in
            XCTAssertEqual(err as? ConfigError, .backingStoreMismatch(backing: "http://127.0.0.1:9999", engine: "http://127.0.0.1:6767"))
        }
    }
    func testIsLoopback() {
        XCTAssertTrue(isLoopback(URL(string: "http://127.0.0.1:6767")!))
        XCTAssertTrue(isLoopback(URL(string: "http://localhost:11434")!))
        XCTAssertFalse(isLoopback(URL(string: "http://0.0.0.0:6767")!))
        XCTAssertFalse(isLoopback(URL(string: "https://api.supermemory.ai")!))
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter InvariantTests`
Expected: FAIL — `validateInvariant` / `isLoopback` not defined.

- [ ] **Step 3: Write minimal implementation** — append to `MnemoConfig.swift`:

```swift
public func isLoopback(_ url: URL) -> Bool {
    guard let host = url.host else { return false }
    return host == "127.0.0.1" || host == "localhost"
}

extension MnemoConfig {
    /// The first line of the invariant: refuse any non-loopback host and any backing-store/engine mismatch.
    public func validateInvariant() throws {
        if !isLoopback(engine.baseURL) {
            throw ConfigError.notLoopback(field: "engine.base_url", value: engine.baseURL.absoluteString)
        }
        if !isLoopback(model.runtimeBaseURL) {
            throw ConfigError.notLoopback(field: "model.runtime_base_url", value: model.runtimeBaseURL.absoluteString)
        }
        if !isLoopback(smfs.backingStore) {
            throw ConfigError.notLoopback(field: "smfs.backing_store", value: smfs.backingStore.absoluteString)
        }
        if smfs.backingStore != engine.baseURL {
            throw ConfigError.backingStoreMismatch(backing: smfs.backingStore.absoluteString, engine: engine.baseURL.absoluteString)
        }
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --filter InvariantTests`
Expected: PASS (4 tests).

- [ ] **Step 5: Commit**

```bash
git add -A && git commit -m "feat(core): loopback invariant validation (fails build on non-loopback config)"
```

---

### Task 5: Health models

**Files:**
- Create: `Sources/MnemoCore/StackHealth.swift`
- Test: `Tests/MnemoCoreTests/StackHealthTests.swift`

**Interfaces:**
- Produces: `struct ProcessState { name; isRunning; boundAddress: String?; var isLoopback: Bool }`; `struct StackHealth { ollama; engine; smfs; var allHealthyAndLoopback: Bool }`.

- [ ] **Step 1: Write the failing test**

```swift
import XCTest
@testable import MnemoCore

final class StackHealthTests: XCTestCase {
    func testLoopbackDetection() {
        XCTAssertTrue(ProcessState(name: "e", isRunning: true, boundAddress: "127.0.0.1:6767").isLoopback)
        XCTAssertFalse(ProcessState(name: "e", isRunning: true, boundAddress: "0.0.0.0:6767").isLoopback)
        XCTAssertFalse(ProcessState(name: "e", isRunning: true, boundAddress: nil).isLoopback)
    }
    func testAllHealthy() {
        let ok = ProcessState(name: "x", isRunning: true, boundAddress: "127.0.0.1:1")
        XCTAssertTrue(StackHealth(ollama: ok, engine: ok, smfs: ok).allHealthyAndLoopback)
        let down = ProcessState(name: "x", isRunning: false, boundAddress: nil)
        XCTAssertFalse(StackHealth(ollama: ok, engine: down, smfs: ok).allHealthyAndLoopback)
    }
}
```

- [ ] **Step 2: Run to verify fail** — `swift test --filter StackHealthTests` → FAIL.

- [ ] **Step 3: Implement** `Sources/MnemoCore/StackHealth.swift`:

```swift
public struct ProcessState: Equatable, Sendable {
    public let name: String
    public let isRunning: Bool
    public let boundAddress: String?   // "127.0.0.1:6767" or nil if unknown/down
    public init(name: String, isRunning: Bool, boundAddress: String?) {
        self.name = name; self.isRunning = isRunning; self.boundAddress = boundAddress
    }
    public var isLoopback: Bool {
        guard let a = boundAddress else { return false }
        return a.hasPrefix("127.0.0.1:") || a.hasPrefix("localhost:")
    }
}

public struct StackHealth: Equatable, Sendable {
    public let ollama: ProcessState
    public let engine: ProcessState
    public let smfs: ProcessState
    public init(ollama: ProcessState, engine: ProcessState, smfs: ProcessState) {
        self.ollama = ollama; self.engine = engine; self.smfs = smfs
    }
    public var allHealthyAndLoopback: Bool {
        [ollama, engine, smfs].allSatisfy { $0.isRunning && $0.isLoopback }
    }
}
```

- [ ] **Step 4: Run to verify pass** — `swift test --filter StackHealthTests` → PASS (2 tests).

- [ ] **Step 5: Commit** — `git add -A && git commit -m "feat(core): ProcessState + StackHealth models"`

---

### Task 6: HTTP health probe

**Files:**
- Create: `Sources/MnemoSupervisor/HealthProbe.swift`
- Test: `Tests/MnemoSupervisorTests/HealthProbeTests.swift`

**Interfaces:**
- Produces: `protocol HealthProbe: Sendable { func isUp(_ url: URL) async -> Bool }`; `struct HTTPHealthProbe: HealthProbe` (init takes a `URLSession`).

- [ ] **Step 1: Write the failing test** (uses a stub `URLProtocol`, no real network):

```swift
import XCTest
@testable import MnemoSupervisor

final class HealthProbeTests: XCTestCase {
    func testUpWhenResponds() async {
        StubURLProtocol.handler = { _ in (HTTPURLResponse(url: URL(string: "http://127.0.0.1:6767")!, statusCode: 200, httpVersion: nil, headerFields: nil)!, Data()) }
        let cfg = URLSessionConfiguration.ephemeral; cfg.protocolClasses = [StubURLProtocol.self]
        let probe = HTTPHealthProbe(session: URLSession(configuration: cfg))
        let up = await probe.isUp(URL(string: "http://127.0.0.1:6767/health")!)
        XCTAssertTrue(up)
    }
    func testDownWhenError() async {
        StubURLProtocol.handler = { _ in throw URLError(.cannotConnectToHost) }
        let cfg = URLSessionConfiguration.ephemeral; cfg.protocolClasses = [StubURLProtocol.self]
        let probe = HTTPHealthProbe(session: URLSession(configuration: cfg))
        let up = await probe.isUp(URL(string: "http://127.0.0.1:6767/health")!)
        XCTAssertFalse(up)
    }
}

final class StubURLProtocol: URLProtocol {
    nonisolated(unsafe) static var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for r: URLRequest) -> URLRequest { r }
    override func startLoading() {
        do {
            let (resp, data) = try Self.handler!(request)
            client?.urlProtocol(self, didReceive: resp, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch { client?.urlProtocol(self, didFailWithError: error) }
    }
    override func stopLoading() {}
}
```

- [ ] **Step 2: Run to verify fail** — `swift test --filter HealthProbeTests` → FAIL.

- [ ] **Step 3: Implement** `Sources/MnemoSupervisor/HealthProbe.swift`:

```swift
import Foundation

public protocol HealthProbe: Sendable {
    func isUp(_ url: URL) async -> Bool
}

public struct HTTPHealthProbe: HealthProbe {
    let session: URLSession
    public init(session: URLSession = .shared) { self.session = session }
    public func isUp(_ url: URL) async -> Bool {
        var req = URLRequest(url: url); req.httpMethod = "GET"; req.timeoutInterval = 2
        do {
            let (_, resp) = try await session.data(for: req)
            guard let http = resp as? HTTPURLResponse else { return false }
            return http.statusCode < 500
        } catch { return false }
    }
}
```

- [ ] **Step 4: Run to verify pass** — `swift test --filter HealthProbeTests` → PASS (2 tests).

- [ ] **Step 5: Commit** — `git add -A && git commit -m "feat(supervisor): HTTP health probe with URLProtocol-stubbed tests"`

---

### Task 7: Process supervisor (ordered start + health)

**Files:**
- Create: `Sources/MnemoSupervisor/ProcessSupervisor.swift`
- Test: `Tests/MnemoSupervisorTests/ProcessSupervisorTests.swift`

**Interfaces:**
- Consumes: `HealthProbe` (Task 6), `MnemoConfig`, `StackHealth`, `ProcessState` (MnemoCore).
- Produces: `enum ManagedProcess: String, CaseIterable { case ollama, engine, smfs }` (declaration order = start order); `protocol ProcessLauncher: Sendable { func launch(_:) async throws; func terminate(_:) async; func boundAddress(_:) async -> String? }`; `actor ProcessSupervisor` with `init(config:launcher:probe:)`, `func startAll() async throws`, `func health() async -> StackHealth`, `enum SupervisorError: Error { case failedToStart(ManagedProcess) }`.

- [ ] **Step 1: Write the failing test** (fakes; asserts start order + health):

```swift
import XCTest
@testable import MnemoSupervisor
@testable import MnemoCore

actor FakeLauncher: ProcessLauncher {
    var launched: [ManagedProcess] = []
    func launch(_ p: ManagedProcess) async throws { launched.append(p) }
    func terminate(_ p: ManagedProcess) async {}
    func boundAddress(_ p: ManagedProcess) async -> String? {
        switch p { case .ollama: "127.0.0.1:11434"; case .engine: "127.0.0.1:6767"; case .smfs: "127.0.0.1:2049" }
    }
}
struct AlwaysUp: HealthProbe { func isUp(_ url: URL) async -> Bool { true } }

final class ProcessSupervisorTests: XCTestCase {
    func testStartsInDependencyOrder() async throws {
        let launcher = FakeLauncher()
        let sup = ProcessSupervisor(config: try MnemoConfig.load(from: ConfigTests.sample), launcher: launcher, probe: AlwaysUp())
        try await sup.startAll()
        let order = await launcher.launched
        XCTAssertEqual(order, [.ollama, .engine, .smfs])
    }
    func testHealthAllLoopback() async throws {
        let sup = ProcessSupervisor(config: try MnemoConfig.load(from: ConfigTests.sample), launcher: FakeLauncher(), probe: AlwaysUp())
        try await sup.startAll()
        let h = await sup.health()
        XCTAssertTrue(h.allHealthyAndLoopback)
    }
}
```
(`ConfigTests.sample` is in the MnemoCore test target; duplicate the sample string into this file's top-level `let` if the targets can't share — copy the sample verbatim from Task 3 to avoid a cross-target reference.)

- [ ] **Step 2: Run to verify fail** — `swift test --filter ProcessSupervisorTests` → FAIL.

- [ ] **Step 3: Implement** `Sources/MnemoSupervisor/ProcessSupervisor.swift`:

```swift
import Foundation
import MnemoCore

public enum ManagedProcess: String, CaseIterable, Sendable {
    case ollama, engine, smfs   // declaration order == start order
}

public protocol ProcessLauncher: Sendable {
    func launch(_ p: ManagedProcess) async throws
    func terminate(_ p: ManagedProcess) async
    func boundAddress(_ p: ManagedProcess) async -> String?
}

public enum SupervisorError: Error, Equatable { case failedToStart(ManagedProcess) }

public actor ProcessSupervisor {
    let config: MnemoConfig
    let launcher: ProcessLauncher
    let probe: HealthProbe

    public init(config: MnemoConfig, launcher: ProcessLauncher, probe: HealthProbe) {
        self.config = config; self.launcher = launcher; self.probe = probe
    }

    func healthURL(_ p: ManagedProcess) -> URL {
        switch p {
        case .ollama: return config.model.runtimeBaseURL
        case .engine: return config.engine.baseURL
        case .smfs:   return config.engine.baseURL   // smfs backs onto the engine
        }
    }

    public func startAll() async throws {
        try config.validateInvariant()
        for p in ManagedProcess.allCases {
            try await launcher.launch(p)
            if !(await waitUntilUp(p)) { throw SupervisorError.failedToStart(p) }
        }
    }

    func waitUntilUp(_ p: ManagedProcess, attempts: Int = 20) async -> Bool {
        for _ in 0..<attempts {
            if await probe.isUp(healthURL(p)) { return true }
            try? await Task.sleep(for: .milliseconds(250))
        }
        return false
    }

    func state(_ p: ManagedProcess) async -> ProcessState {
        let addr = await launcher.boundAddress(p)
        let up = await probe.isUp(healthURL(p))
        return ProcessState(name: p.rawValue, isRunning: up, boundAddress: addr)
    }

    public func health() async -> StackHealth {
        StackHealth(ollama: await state(.ollama), engine: await state(.engine), smfs: await state(.smfs))
    }
}
```

- [ ] **Step 4: Run to verify pass** — `swift test --filter ProcessSupervisorTests` → PASS (2 tests).

- [ ] **Step 5: Commit** — `git add -A && git commit -m "feat(supervisor): ordered ProcessSupervisor with fake-driven tests"`

---

### Task 8: Loopback socket audit (lsof parser)

**Files:**
- Create: `Sources/MnemoSupervisor/LoopbackAudit.swift`
- Test: `Tests/MnemoSupervisorTests/LoopbackAuditTests.swift`

**Interfaces:**
- Produces: `struct ListeningSocket: Equatable { let command: String; let pid: Int; let address: String }`; `enum LoopbackAudit { static func parseLSOF(_:) -> [ListeningSocket]; static func nonLoopback(_:) -> [ListeningSocket] }`.

- [ ] **Step 1: Write the failing test** (fixture is real `lsof -iTCP -sTCP:LISTEN -n -P` output):

```swift
import XCTest
@testable import MnemoSupervisor

final class LoopbackAuditTests: XCTestCase {
    static let fixture = """
    COMMAND   PID USER   FD   TYPE DEVICE SIZE/OFF NODE NAME
    ollama    501 m3     8u  IPv4  0x1      0t0  TCP 127.0.0.1:11434 (LISTEN)
    supermem  502 m3    10u  IPv4  0x2      0t0  TCP 127.0.0.1:6767 (LISTEN)
    rogue     503 m3    11u  IPv4  0x3      0t0  TCP 0.0.0.0:8080 (LISTEN)
    """
    func testParsesSockets() {
        let s = LoopbackAudit.parseLSOF(Self.fixture)
        XCTAssertEqual(s.count, 3)
        XCTAssertEqual(s[0], ListeningSocket(command: "ollama", pid: 501, address: "127.0.0.1:11434"))
    }
    func testFlagsNonLoopback() {
        let bad = LoopbackAudit.nonLoopback(LoopbackAudit.parseLSOF(Self.fixture))
        XCTAssertEqual(bad.map(\.address), ["0.0.0.0:8080"])
    }
}
```

- [ ] **Step 2: Run to verify fail** — `swift test --filter LoopbackAuditTests` → FAIL.

- [ ] **Step 3: Implement** `Sources/MnemoSupervisor/LoopbackAudit.swift`:

```swift
import Foundation

public struct ListeningSocket: Equatable, Sendable {
    public let command: String; public let pid: Int; public let address: String
}

public enum LoopbackAudit {
    public static func parseLSOF(_ text: String) -> [ListeningSocket] {
        var out: [ListeningSocket] = []
        for line in text.split(separator: "\n").dropFirst() { // drop header
            let cols = line.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
            guard cols.count >= 9, let pid = Int(cols[1]),
                  let nameIdx = cols.firstIndex(where: { $0.contains(":") && ($0.contains(".") ) }) else { continue }
            out.append(ListeningSocket(command: cols[0], pid: pid, address: cols[nameIdx]))
        }
        return out
    }
    public static func nonLoopback(_ sockets: [ListeningSocket]) -> [ListeningSocket] {
        sockets.filter { !($0.address.hasPrefix("127.0.0.1:") || $0.address.hasPrefix("[::1]:") || $0.address.hasPrefix("localhost:")) }
    }
}
```

- [ ] **Step 4: Run to verify pass** — `swift test --filter LoopbackAuditTests` → PASS (2 tests).

- [ ] **Step 5: Commit** — `git add -A && git commit -m "feat(supervisor): lsof parser + non-loopback audit"`

---

### Task 9: Real launcher, `mnemoctl` CLI, launchd, integration smoke

**Files:**
- Create: `Sources/MnemoSupervisor/SystemProcessLauncher.swift`
- Modify: `Sources/mnemoctl/main.swift`
- Create: `Resources/launchd/ai.mnemo.stack.plist`
- Create: `scripts/smoke.sh`

**Interfaces:**
- Consumes: everything above.
- Produces: `struct SystemProcessLauncher: ProcessLauncher` (launches real `ollama`, the engine binary, and the SMFS mount from config; `boundAddress` shells `lsof`); `mnemoctl` subcommands `health`, `audit`, `start`.

> These steps touch **real external binaries**, so they are integration/manual steps (the unit-testable logic already shipped in Tasks 2–8). Verify by running commands and observing output.

- [ ] **Step 1: Implement `SystemProcessLauncher`** `Sources/MnemoSupervisor/SystemProcessLauncher.swift`:

```swift
import Foundation
import MnemoCore

public struct SystemProcessLauncher: ProcessLauncher {
    let config: MnemoConfig
    public init(config: MnemoConfig) { self.config = config }

    public func launch(_ p: ManagedProcess) async throws {
        switch p {
        case .ollama:
            // Expect `ollama serve` already managed by the user/launchd; ensure the model is pulled.
            try run("/usr/bin/env", ["ollama", "pull", config.model.synthesis])
        case .engine:
            // Launch the self-hosted Supermemory binary bound to loopback with BYOM=ollama.
            // Path/flags depend on the installed binary; wire the real command here.
            try run("/usr/bin/env", ["supermemory", "serve",
                                     "--bind", config.engine.baseURL.absoluteString,
                                     "--byom", "ollama", "--embeddings", "local"])
        case .smfs:
            try run("/usr/bin/env", ["smfs", "mount", config.smfs.mountPoint,
                                     "--backing-store", config.smfs.backingStore.absoluteString])
        }
    }
    public func terminate(_ p: ManagedProcess) async { /* signal the launched process group */ }
    public func boundAddress(_ p: ManagedProcess) async -> String? {
        let port = p == .ollama ? "11434" : "6767"
        let out = (try? capture("/usr/sbin/lsof", ["-iTCP:\(port)", "-sTCP:LISTEN", "-n", "-P"])) ?? ""
        return LoopbackAudit.parseLSOF(out).first?.address
    }

    @discardableResult func run(_ path: String, _ args: [String]) throws -> Int32 {
        let p = Process(); p.executableURL = URL(fileURLWithPath: path); p.arguments = args
        try p.run(); p.waitUntilExit(); return p.terminationStatus
    }
    func capture(_ path: String, _ args: [String]) throws -> String {
        let p = Process(); p.executableURL = URL(fileURLWithPath: path); p.arguments = args
        let pipe = Pipe(); p.standardOutput = pipe; try p.run(); p.waitUntilExit()
        return String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
    }
}
```

- [ ] **Step 2: Implement `mnemoctl`** `Sources/mnemoctl/main.swift`:

```swift
import Foundation
import MnemoCore
import MnemoSupervisor

let configText = (try? String(contentsOfFile: "mnemo.toml", encoding: .utf8)) ?? ""
guard let config = try? MnemoConfig.load(from: configText) else {
    FileHandle.standardError.write(Data("mnemo.toml missing or invalid\n".utf8)); exit(2)
}
do { try config.validateInvariant() } catch {
    FileHandle.standardError.write(Data("INVARIANT VIOLATION: \(error)\n".utf8)); exit(3)
}

let arg = CommandLine.arguments.dropFirst().first ?? "health"
let sup = ProcessSupervisor(config: config, launcher: SystemProcessLauncher(config: config), probe: HTTPHealthProbe())

switch arg {
case "start":
    try await sup.startAll(); print("stack up")
case "audit":
    let launcher = SystemProcessLauncher(config: config)
    let out = (try? launcher.capture("/usr/sbin/lsof", ["-iTCP", "-sTCP:LISTEN", "-n", "-P"])) ?? ""
    let bad = LoopbackAudit.nonLoopback(LoopbackAudit.parseLSOF(out))
    if bad.isEmpty { print("loopback OK") } else { print("NON-LOOPBACK: \(bad)"); exit(4) }
default:
    let h = await sup.health(); print("health: \(h)  allHealthyAndLoopback=\(h.allHealthyAndLoopback)")
}
```
(Mark `capture` `public` on `SystemProcessLauncher` so `mnemoctl` can call it.)

- [ ] **Step 3: Create the launchd plist** `Resources/launchd/ai.mnemo.stack.plist` (KeepAlive, RunAtLoad; `ProgramArguments` → the built `mnemoctl start`). Install to `~/Library/LaunchAgents/` in the smoke script.

- [ ] **Step 4: Create `scripts/smoke.sh`** (the M0 integration acceptance — run with the real binaries installed):

```bash
#!/usr/bin/env bash
set -euo pipefail
swift build
# AT-M0.1/0.2: start stack, prove loopback-only
.build/debug/mnemoctl start
.build/debug/mnemoctl audit                     # expect "loopback OK"
lsof -iTCP -sTCP:LISTEN -n -P | grep -E '6767|11434'  # expect only 127.0.0.1
.build/debug/mnemoctl health                    # expect allHealthyAndLoopback=true
echo "SMOKE OK"
```

- [ ] **Step 5: Run acceptance & commit**

Run (with Ollama/engine/SMFS installed, **network off**): `chmod +x scripts/smoke.sh && ./scripts/smoke.sh`
Expected: `loopback OK`, only `127.0.0.1` bindings, `allHealthyAndLoopback=true`, `SMOKE OK`. This satisfies **AT-M0.1, AT-M0.2, AT-M0.3** ([PLAN.md → M0](../../../PLAN.md#m0--bootstrap--process-supervision)).
```bash
git add -A && git commit -m "feat(supervisor): real launcher + mnemoctl + launchd + smoke (M0 complete)"
```

---

## M0 Definition of Done
- [ ] `swift test` green (Tasks 2–8), network-off.
- [ ] `scripts/smoke.sh` prints `SMOKE OK` with real binaries, network-off (AT-M0.1–0.3).
- [ ] `mnemoctl audit` reports loopback-only; a non-loopback binding makes it exit non-zero.
- [ ] A non-loopback `mnemo.toml` makes `mnemoctl` exit 3 before starting anything (invariant gate).
- [ ] launchd plist installed; killing a process is recovered (extend `SystemProcessLauncher.terminate`/relaunch for AT-M0.5 — add a KeepAlive test once the real binary paths are wired).
