import Foundation
import MnemoCore
import MnemoOrchestrator
import MnemoSupervisor

// Line-buffer stdout even when piped, so harnesses/tests that kill a slow run
// still see every event emitted before the kill (otherwise Swift's default
// full buffering loses the partial transcript).
setvbuf(stdout, nil, _IOLBF, 0)

func findConfig() -> String? {
    let candidates = [
        FileManager.default.currentDirectoryPath + "/mnemo.toml",
        NSHomeDirectory() + "/Documents/6767/mnemo.toml",
    ]
    for c in candidates where FileManager.default.fileExists(atPath: c) {
        return try? String(contentsOfFile: c, encoding: .utf8)
    }
    return nil
}

guard let configText = findConfig() else {
    FileHandle.standardError.write(Data("mnemo.toml not found\n".utf8))
    exit(2)
}
guard let config = try? MnemoConfig.load(from: configText) else {
    FileHandle.standardError.write(Data("mnemo.toml invalid\n".utf8))
    exit(2)
}
do { try config.validateInvariant() } catch {
    FileHandle.standardError.write(Data("INVARIANT VIOLATION: \(error)\n".utf8))
    exit(3)
}

let arg = CommandLine.arguments.dropFirst().first ?? "health"
if MnemoCLI.wantsHelp {
    MnemoCLI.printHelp(command: arg == "health" ? nil : arg)
    exit(0)
}
let launcher = SystemProcessLauncher(config: config)
let sup = ProcessSupervisor(config: config, launcher: launcher, probe: HTTPHealthProbe())

switch arg {
case "start":
    try await sup.startAll()
    print("stack up")
case "stop":
    await sup.stopAll()
    print("stack stopped")
case "restart-engine":
    try await sup.restart(.engine)
    print("engine restarted")
case "audit":
    runAudit(launcher: launcher)
case "health":
    let h = await sup.health()
    printHealth(h, config: config, verbose: MnemoCLI.verbose)
    if !h.allHealthyAndLoopback { exit(MnemoExitCode.healthFailure.rawValue) }
case "ask":
    // Headless query path — same wiring as the app (AT-M1.* from the terminal).
    // --then <q2> runs a second turn threading the first turn as history
    // (conversation follow-ups, testable headlessly).
    var askArgs = Array(CommandLine.arguments.dropFirst(2))
    var followUp: String?
    if let i = askArgs.firstIndex(of: "--then"), i + 1 < askArgs.count {
        followUp = askArgs[(i + 1)...].joined(separator: " ")
        askArgs.removeSubrange(i...)
    }
    let q = askArgs.filter { $0 != "--verify" }.joined(separator: " ")
    guard !q.isEmpty else {
        FileHandle.standardError.write(Data("usage: mnemoctl ask [--verify] <question> [--then <follow-up>]\n".utf8))
        exit(64)
    }
    let key = ProcessInfo.processInfo.environment["SUPERMEMORY_API_KEY"] ?? ""
    let engine = EngineClient(baseURL: config.engine.baseURL, apiKey: key)
    let ollama = OllamaClient(baseURL: config.model.runtimeBaseURL,
                              model: config.model.synthesis,
                              keepAlive: config.model.keepAlive)
    let verify = CommandLine.arguments.contains("--verify")
    let service = QueryService(
        retriever: engine,
        generator: ollama,
        spans: SpanResolver(docs: engine),
        defaults: SearchDefaults(searchMode: config.retrieval.defaultMode,
                                 rerank: config.retrieval.rerank,
                                 threshold: config.retrieval.threshold,
                                 limit: config.retrieval.limit,
                                 container: "mnemo"),
        mountRoot: (config.smfs.mountPoint as NSString).expandingTildeInPath,
        profiles: engine,
        assembler: ContextAssembler(tokenBudget: 8000),
        effort: EffortPolicy(routing: config.effort.routing,
                             extraction: config.effort.extraction,
                             synthesis: config.effort.synthesis,
                             multihop: config.effort.multihop),
        verifier: verify ? CitationVerifier(backend: LocalVerificationBackend(generator: ollama)) : nil,
        documentSearchEnabled: true,
        conversationSink: engine,
        chatRecallEnabled: true)
    let logSink = makeLogSink()
    func runAsk(_ question: String, history: [Turn]) async throws -> String {
        var sawToken = false
        var answer = ""
        var entry = QueryLogEntry()
        entry.modelId = config.model.synthesis
        let t0 = Date()
        var hopCount = 0
        var verified = 0
        var checked = 0
        for try await event in service.ask(question, history: history) {
            switch event {
            case .routed(let intent, let effort):
                entry.routeIntent = intent
                entry.effortTier = effort
                if MnemoCLI.verbose { print("[route] \(intent) (effort: \(effort))") }
                else { print("[route] \(intent) (effort: \(effort))") }
            case .understanding(let phrase):
                if MnemoCLI.verbose { print("[understanding] \(phrase)") }
            case .sources(let cards):
                // Event-order proof for AT-M1.4: this line must print before any token.
                print("[sources] \(cards.map { "\($0.title) <\($0.path)>" }.joined(separator: ", "))")
            case .token(let t):
                if entry.firstTokenMs == nil {
                    entry.firstTokenMs = Int(Date().timeIntervalSince(t0) * 1000)
                }
                if !sawToken { print("[answer] ", terminator: ""); sawToken = true }
                print(t, terminator: "")
                fflush(stdout)
                answer += t
            case .retrying(let reason):
                print("\n[retrying] \(reason)"); sawToken = false; answer = ""
            case .entities(let ents):
                if MnemoCLI.verbose { print("\n[entities] \(ents.joined(separator: " · "))") }
            case .reasoning(let steps):
                hopCount += 1
                if MnemoCLI.verbose { print("[reasoning] \(steps.joined(separator: " → "))") }
            case .citation(let idx, let supported):
                checked += 1
                if supported { verified += 1 }
                if !supported { print("\n[citation] sentence \(idx): UNSUPPORTED") }
            case .suggestions(let chips):
                if MnemoCLI.verbose { print("\n[follow-ups] \(chips.joined(separator: " · "))") }
            case .related(let docs):
                if MnemoCLI.verbose { print("[see also] \(docs.map(\.title).joined(separator: " · "))") }
            case .state(let terminal):
                entry.terminalState = String(describing: terminal)
                print("[state] \(terminal): \(NotchReducer.message(for: terminal))")
            case .done:
                print("\n[done]")
            }
        }
        entry.retrievalHopCount = hopCount
        entry.totalMs = Int(Date().timeIntervalSince(t0) * 1000)
        entry.egressBlockedCount = LoopbackGuardURLProtocol.blockedCount
        if checked > 0 { entry.verificationPassRate = Double(verified) / Double(checked) }
        await logSink.emit(entry)
        return answer
    }
    do {
        let firstAnswer = try await runAsk(q, history: [])
        if let followUp {
            print("[turn2] \(followUp)")
            _ = try await runAsk(followUp, history: [Turn(question: q, answer: firstAnswer, sources: [])])
        }
    } catch {
        // A failed query is a defined output, not a crash trace.
        FileHandle.standardError.write(Data("\n[error] \(error)\n".utf8))
        exit(1)
    }
case "ingest-status":
    let key = ProcessInfo.processInfo.environment["SUPERMEMORY_API_KEY"] ?? ""
    let engine = EngineClient(baseURL: config.engine.baseURL, apiKey: key)
    let index = IngestIndex(docs: engine, container: "mnemo")
    await index.refresh()
    let docs = try await engine.documentsList(container: "mnemo")
    for d in docs.sorted(by: { ($0.filepath ?? "") < ($1.filepath ?? "") }) {
        let eff = MediaCompanion.effectiveState(of: d, in: docs)
        let raw = eff == d.state ? "" : " (engine: \(d.state.rawValue))"
        let kind = MediaCompanion.companionOf(d).map { " companion-of \($0)" } ?? ""
        print("\(eff.rawValue.padding(toLength: 10, withPad: " ", startingAt: 0)) \(d.filepath ?? "-")\(raw)\(kind)  [\(d.id)]")
    }
    print("queueDepth=\(await index.queueDepth)")
case "watch-ingest":
    // Poll the engine and print state transitions as they happen (AT-M2.1 evidence).
    let seconds = Int(CommandLine.arguments.dropFirst(2).first ?? "30") ?? 30
    let key = ProcessInfo.processInfo.environment["SUPERMEMORY_API_KEY"] ?? ""
    let engine = EngineClient(baseURL: config.engine.baseURL, apiKey: key)
    let index = IngestIndex(docs: engine, container: "mnemo")
    let stream = await index.events()
    let watcher = Task {
        for await e in stream {
            let from = e.from.map(\.rawValue) ?? "∅"
            print("[\(ISO8601DateFormatter().string(from: Date()))] \(e.path ?? e.docId): \(from) → \(e.to.rawValue)")
            fflush(stdout)
        }
    }
    let deadline = Date().addingTimeInterval(TimeInterval(seconds))
    while Date() < deadline {
        await index.refresh()
        try await Task.sleep(for: .milliseconds(300))
    }
    await index.finishEvents()
    _ = await watcher.value
    print("watch done, queueDepth=\(await index.queueDepth)")
case "profile":
    let q = CommandLine.arguments.dropFirst(2).joined(separator: " ")
    let key = ProcessInfo.processInfo.environment["SUPERMEMORY_API_KEY"] ?? ""
    let engine = EngineClient(baseURL: config.engine.baseURL, apiKey: key)
    let p = try await engine.profile(q.isEmpty ? "general" : q, container: "mnemo")
    print("static:")
    for s in p.statics { print("  • \(s)") }
    print("dynamic:")
    for d in p.dynamics { print("  • \(d)") }
    print("memories (query-relevant):")
    for m in p.memories { print("  • [\(String(format: "%.2f", m.similarity))] \(m.memory)") }
case "agentic":
    let q = CommandLine.arguments.dropFirst(2).joined(separator: " ")
    guard !q.isEmpty else {
        FileHandle.standardError.write(Data("usage: mnemoctl agentic <question>\n".utf8)); exit(64)
    }
    let smfsKey = (try? String(contentsOfFile: NSHomeDirectory() + "/.supermemory/data/api-key",
                               encoding: .utf8))?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    let surface = SMFSGrep(smfsPath: NSHomeDirectory() + "/.local/bin/smfs",
                           containerTag: "mnemo",
                           apiKey: smfsKey,
                           apiURL: config.engine.baseURL.absoluteString,
                           mountRoot: (config.smfs.mountPoint as NSString).expandingTildeInPath)
    let planner = LLMHopPlanner(generator: OllamaClient(
        baseURL: config.model.runtimeBaseURL, model: config.model.synthesis,
        keepAlive: config.model.keepAlive))
    let agentic = AgenticGrep(surface: surface, planner: planner, maxHops: 6)
    let result = try await agentic.run(q, scope: nil)
    print("── hop trace ──")
    for h in result.hops {
        print("\(h.hop). [\(h.kind)] \"\(h.query)\" → \(h.paths.filter { !$0.isEmpty }.sorted())")
        print("   rationale: \(h.rationale)")
    }
    print("── evidence (\(result.evidence.count)) ──")
    for e in result.evidence { print("  • [\(e.source.path.isEmpty ? "memory" : e.source.path)] \(e.memory.prefix(100))") }
case "media-sync":
    // On-device extraction pass: failed media docs get searchable companions.
    let key = ProcessInfo.processInfo.environment["SUPERMEMORY_API_KEY"] ?? ""
    let engine = EngineClient(baseURL: config.engine.baseURL, apiKey: key)
    let mountRoot = (config.smfs.mountPoint as NSString).expandingTildeInPath
    let ingestor = MediaIngestor(creator: engine, container: "mnemo", mountRoot: mountRoot)
    let docs = try await engine.documentsList(container: "mnemo")
    let worklist = MediaCompanion.needingExtraction(docs: docs)
    print("failed media without companions: \(worklist.map { $0.filepath ?? $0.id })")
    let n = await ingestor.sync(docs: docs)
    print("companions created: \(n)")
case "memory":
    // Subcommands: add <text> | supersede-check <text> | forget <id> | history <id> | list
    let sub = CommandLine.arguments.dropFirst(2).first ?? "list"
    let ct = CommandLine.arguments.contains("--container")
        ? CommandLine.arguments[CommandLine.arguments.firstIndex(of: "--container")! + 1] : "mnemo"
    // Strip the --container flag+value out of the free-text argument.
    var restArgs = Array(CommandLine.arguments.dropFirst(3))
    if let i = restArgs.firstIndex(of: "--container") {
        restArgs.removeSubrange(i...min(i + 1, restArgs.count - 1))
    }
    let rest = restArgs.joined(separator: " ")
    let key = ProcessInfo.processInfo.environment["SUPERMEMORY_API_KEY"] ?? ""
    let engine = EngineClient(baseURL: config.engine.baseURL, apiKey: key)
    let dyn = MemoryDynamics(store: engine, container: ct, detector: LexicalContradiction())
    switch sub {
    case "list":
        for m in try await engine.listMemories(container: ct) where m.isLatest && !m.isForgotten {
            print("\(m.id) v\(m.version)\(m.isStatic ? " [static]" : "")  \(m.memory)")
        }
    case "add":
        try await dyn.onNewFacts([rest], from: "cli")
        print("processed (superseded a contradiction in place, or created if novel)")
    case "forget":
        try await dyn.softDelete(rest, reason: .userRetraction)
        print("forgotten \(rest)")
    case "history":
        for v in try await dyn.history(of: rest) { print("v\(v.version): \(v.memory)") }
    case "strengthen":
        let ledger = StrengthLedger(path: NSHomeDirectory() + "/.supermemory/mnemo-strength.json")
        let memId = restArgs.first ?? ""
        let times = restArgs.count > 1 ? (Int(restArgs[1]) ?? 1) : 1
        for _ in 0..<times { await ledger.strengthen(memId) }
        print("strengthened \(memId) \(times)x, count=\(await ledger.record(memId)?.retrievalCount ?? 0)")
    default:
        print("usage: mnemoctl memory [list|add <text>|forget <id>|history <id>|strengthen <id> <n>] [--container <tag>]")
    }
case "backstop":
    // Debug surface for the literal-keyword rescue: shows terms, coverage,
    // and the synthetic evidence it would inject for a query.
    let q = CommandLine.arguments.dropFirst(2).joined(separator: " ")
    guard !q.isEmpty else { print("usage: mnemoctl backstop <query>"); exit(2) }
    let mount = (config.smfs.mountPoint as NSString).expandingTildeInPath
    let terms = KeywordBackstop.salientTerms(q)
    print("salient: \(terms.joined(separator: ", "))")
    let (merged, note) = KeywordBackstop.rescue(query: q, evidence: [], mountRoot: mount)
    print("note: \(note ?? "-")")
    for hit in merged {
        print("--- \(hit.source.title) <\(hit.source.path)>")
        print(hit.memory.prefix(400))
    }
case "entity":
    // Beats-Siri #4: knowledge panel for an entity, aggregated across the corpus.
    let name = CommandLine.arguments.dropFirst(2).joined(separator: " ")
    guard !name.isEmpty else { print("usage: mnemoctl entity <name>"); exit(2) }
    let key = ProcessInfo.processInfo.environment["SUPERMEMORY_API_KEY"] ?? ""
    let engine = EngineClient(baseURL: config.engine.baseURL, apiKey: key)
    let hits = try await engine.search(SearchRequest(q: name, searchMode: "memories", rerank: false,
                                                     threshold: 0.35, limit: 15, container: "mnemo"))
    let panel = EntityPanel.build(entity: name, from: hits)
    if panel.facts.isEmpty { print("nothing known about “\(name)”") }
    else {
        print("What I know about \(name):")
        for f in panel.facts.prefix(8) { print("• \(f)") }
        print("From: " + panel.sources.map(\.title).joined(separator: ", "))
    }
case "preferences":
    // Beats-Siri #9: the learned model of the user, explicit and inspectable.
    let key = ProcessInfo.processInfo.environment["SUPERMEMORY_API_KEY"] ?? ""
    let engine = EngineClient(baseURL: config.engine.baseURL, apiKey: key)
    let ledger = StrengthLedger(path: NSHomeDirectory() + "/.supermemory/mnemo-strength.json")
    let memories = (try? await engine.listMemories(container: "mnemo")) ?? []
    print(Preferences.summary(memories: memories, strength: await ledger.counts()))
case "digest":
    // Beats-Siri #5: the proactive "since last time" summary.
    let key = ProcessInfo.processInfo.environment["SUPERMEMORY_API_KEY"] ?? ""
    let engine = EngineClient(baseURL: config.engine.baseURL, apiKey: key)
    let docs = try await engine.documentsList(container: "mnemo")
    let d = Digest.build(readyCount: docs.filter { $0.state == .ready }.count,
                         processingCount: docs.filter { $0.state == .processing || $0.state == .queued }.count,
                         failedCount: docs.filter { $0.state == .error }.count,
                         newSinceLast: docs.count, conflictsResolved: 0)
    print(d.isEmpty ? "(quiet — nothing notable)" : d)
case "sync":
    let sub = CommandLine.arguments.dropFirst(2).first ?? "force"
    let key = ProcessInfo.processInfo.environment["SUPERMEMORY_API_KEY"] ?? ""
    let engine = EngineClient(baseURL: config.engine.baseURL, apiKey: key)
    let smfs = SMFSSync(smfsPath: NSHomeDirectory() + "/.local/bin/smfs")
    let sync = SyncEngine(store: engine, docs: engine, container: "mnemo", forcer: smfs)
    switch sub {
    case "force":
        try await sync.forceSync(); print("forced sync")
    case "self-heal":
        let n = try await sync.selfHeal(); print("orphans healed: \(n)")
    default:
        print("usage: mnemoctl sync [force|self-heal]")
    }
case "dream":
    let key = ProcessInfo.processInfo.environment["SUPERMEMORY_API_KEY"] ?? ""
    let engine = EngineClient(baseURL: config.engine.baseURL, apiKey: key)
    let ct = CommandLine.arguments.contains("--container")
        ? CommandLine.arguments[CommandLine.arguments.firstIndex(of: "--container")! + 1] : "mnemo"
    let ledgerPath = NSHomeDirectory() + "/.supermemory/mnemo-strength.json"
    let ollama = OllamaClient(baseURL: config.model.runtimeBaseURL, model: config.model.synthesis,
                              keepAlive: config.model.keepAlive)
    let consolidator = Consolidator(
        store: engine, ledger: StrengthLedger(path: ledgerPath), container: ct,
        synthesizer: LLMSynthesizer(generator: ollama),
        coldThresholdDays: 30, promoteMinAssertions: 3)
    print("dreaming…")
    try await consolidator.dream()
    print("dream pass complete")
case "inspect":
    let sub = CommandLine.arguments.dropFirst(2).first ?? "show"
    let ct = CommandLine.arguments.contains("--container")
        ? CommandLine.arguments[CommandLine.arguments.firstIndex(of: "--container")! + 1] : "mnemo"
    var restArgs = Array(CommandLine.arguments.dropFirst(3))
    if let i = restArgs.firstIndex(of: "--container") { restArgs.removeSubrange(i...min(i + 1, restArgs.count - 1)) }
    let key = ProcessInfo.processInfo.environment["SUPERMEMORY_API_KEY"] ?? ""
    let engine = EngineClient(baseURL: config.engine.baseURL, apiKey: key)
    let supp = SuppressionLedger(path: NSHomeDirectory() + "/.supermemory/mnemo-suppression.json")
    let inspector = MemoryInspector(store: engine, container: ct, suppression: supp)
    switch sub {
    case "show":
        let snap = try await inspector.snapshot()
        print("STATIC:");  for c in snap.statics { print("  [\(c.id)] \(c.text)") }
        print("DYNAMIC:"); for c in snap.dynamics { print("  [\(c.id)] \(c.text)") }
    case "delete":
        // delete <memId> <exact text…>
        let memId = restArgs.first ?? ""
        let text = restArgs.dropFirst().joined(separator: " ")
        try await inspector.delete(memId, text: text)
        print("deleted \(memId) + suppressed re-ingest")
    case "correct":
        let memId = restArgs.first ?? ""
        let newText = restArgs.dropFirst().joined(separator: " ")
        try await inspector.correct(memId, newText: newText)
        print("corrected \(memId) → \(newText)")
    default:
        print("usage: mnemoctl inspect [show|delete <id> <text>|correct <id> <newText>] [--container <tag>]")
    }
case "egress-check":
    await runEgressCheck(config: config)
case "bench":
    // Latency SLO report (M11): first-token + total, warm-model check, and the
    // same run with a background ingest hammering the engine (no-stall check).
    let key = ProcessInfo.processInfo.environment["SUPERMEMORY_API_KEY"] ?? ""
    let engine = EngineClient(baseURL: config.engine.baseURL, apiKey: key)
    let ollama = OllamaClient(baseURL: config.model.runtimeBaseURL, model: config.model.synthesis, keepAlive: config.model.keepAlive)
    func makeService() -> QueryService {
        QueryService(retriever: engine, generator: ollama, spans: SpanResolver(docs: engine),
                     defaults: SearchDefaults(searchMode: config.retrieval.defaultMode, rerank: config.retrieval.rerank,
                                              threshold: config.retrieval.threshold, limit: config.retrieval.limit, container: "mnemo"),
                     mountRoot: (config.smfs.mountPoint as NSString).expandingTildeInPath, profiles: engine)
    }
    let queries = ["What is my favorite build tool?", "When did I switch to Bazel?",
                   "How often does the staging password rotate?", "What is the search latency target?"]
    func measure(_ label: String) async throws -> [(first: Double, total: Double)] {
        var out: [(Double, Double)] = []
        for q in queries {
            let start = Date(); var firstToken: Double?
            for try await e in makeService().ask(q) {
                if case .token = e, firstToken == nil { firstToken = Date().timeIntervalSince(start) }
            }
            let total = Date().timeIntervalSince(start)
            out.append((firstToken ?? total, total))
            print("  [\(label)] \"\(q.prefix(30))…\" first=\(Int((firstToken ?? total)*1000))ms total=\(Int(total*1000))ms")
        }
        return out
    }
    print("=== idle (warm model) ===")
    let idle = try await measure("idle")
    print("=== under background ingest load ===")
    let loadTask = Task.detached(priority: .background) {
        for i in 0..<20 { _ = try? await engine.documentsList(container: "mnemo"); if i % 5 == 0 { _ = try? await engine.search(SearchRequest(q: "load \(i)", container: "mnemo")) } }
    }
    let underLoad = try await measure("load")
    loadTask.cancel()
    func p95(_ xs: [Double]) -> Double { xs.sorted()[min(xs.count - 1, Int(Double(xs.count) * 0.95))] }
    let idleFirst = idle.map(\.first), loadFirst = underLoad.map(\.first)
    print("--- SLO report ---")
    print("first-token P95 idle=\(Int(p95(idleFirst)*1000))ms  underLoad=\(Int(p95(loadFirst)*1000))ms  (SLA \(config.sla.firstTokenMs)ms)")
    let warm = idleFirst.dropFirst().allSatisfy { $0 < (idleFirst.first ?? 0) * 3 + 2 }
    print("warm-model (no cold-load spike on later queries): \(warm ? "OK" : "REVIEW")")
case "containers":
    // #4: list the Supermemory containers derived from the document set.
    let key = ProcessInfo.processInfo.environment["SUPERMEMORY_API_KEY"] ?? ""
    let engine = EngineClient(baseURL: config.engine.baseURL, apiKey: key)
    let docs = try await engine.documentsList(container: nil)
    let containers = ContainerCatalog.distinct(docs)
    print(containers.isEmpty ? "(no containers)" : containers.joined(separator: "\n"))
case "processing":
    // #3: native processing status.
    let key = ProcessInfo.processInfo.environment["SUPERMEMORY_API_KEY"] ?? ""
    let engine = EngineClient(baseURL: config.engine.baseURL, apiKey: key)
    let procs = try await engine.processing(container: "mnemo")
    if procs.isEmpty { print("nothing processing") }
    for d in procs { print("\(d.status.padding(toLength: 12, withPad: " ", startingAt: 0)) \(d.filepath ?? d.id)") }
case "upload":
    // #2: upload an arbitrary file directly through the engine.
    guard let path = CommandLine.arguments.dropFirst(2).first else {
        FileHandle.standardError.write(Data("usage: mnemoctl upload <path>\n".utf8)); exit(64)
    }
    let key = ProcessInfo.processInfo.environment["SUPERMEMORY_API_KEY"] ?? ""
    let engine = EngineClient(baseURL: config.engine.baseURL, apiKey: key)
    let id = try await engine.uploadFile(URL(fileURLWithPath: (path as NSString).expandingTildeInPath), container: "mnemo")
    print("uploaded, document id: \(id)")
case "context":
    // #6: get/set a container's memory-shaping context prompt.
    let key = ProcessInfo.processInfo.environment["SUPERMEMORY_API_KEY"] ?? ""
    let engine = EngineClient(baseURL: config.engine.baseURL, apiKey: key)
    let ctx = CommandLine.arguments.dropFirst(2).joined(separator: " ")
    if ctx.isEmpty {
        print("context: \(try await engine.containerContext("mnemo") ?? "(none)")")
    } else {
        try await engine.setContainerContext("mnemo", context: ctx)
        print("context set for 'mnemo'")
    }
case "forget-scope":
    // #7: bulk-delete every document in a container.
    guard let tag = CommandLine.arguments.dropFirst(2).first else {
        FileHandle.standardError.write(Data("usage: mnemoctl forget-scope <container>\n".utf8)); exit(64)
    }
    let key = ProcessInfo.processInfo.environment["SUPERMEMORY_API_KEY"] ?? ""
    let engine = EngineClient(baseURL: config.engine.baseURL, apiKey: key)
    let n = try await engine.bulkDelete(container: tag)
    print("deleted \(n) documents from '\(tag)'")
case "chunks":
    // #1: the engine's authoritative chunks for a document.
    guard let docId = CommandLine.arguments.dropFirst(2).first else {
        FileHandle.standardError.write(Data("usage: mnemoctl chunks <docId>\n".utf8)); exit(64)
    }
    let key = ProcessInfo.processInfo.environment["SUPERMEMORY_API_KEY"] ?? ""
    let engine = EngineClient(baseURL: config.engine.baseURL, apiKey: key)
    for c in try await engine.chunks(docId) { print("[\(c.position)] \(c.content.prefix(100))") }
case "hash":
    guard let path = CommandLine.arguments.dropFirst(2).first else {
        FileHandle.standardError.write(Data("usage: mnemoctl hash <path>\n".utf8)); exit(64)
    }
    print(try ContentHash.sha256(of: URL(fileURLWithPath: (path as NSString).expandingTildeInPath)))
default:
    if arg == "--help" || arg == "-h" {
        MnemoCLI.printHelp()
        exit(0)
    }
    MnemoCLI.printHelp()
    exit(MnemoExitCode.usage.rawValue)
}
