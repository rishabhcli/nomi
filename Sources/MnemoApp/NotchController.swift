import AppKit
import SwiftUI
import MnemoOrchestrator
import MnemoCore

@MainActor
final class NotchController {
    let panel: NotchPanel
    let vm: NotchViewModel
    let sync: BackgroundSync
    let scheduler: WorkScheduler
    let dictation: Dictation
    let narrator: Narrator
    let handler: AppCommandHandler
    let notchRect: CGRect
    let screenFrame: CGRect
    /// Deep-observability bus for the dev dashboard; nil unless devtools enabled.
    let devTrace: DevTrace?
    private var syncTask: Task<Void, Never>?

    init(config: MnemoConfig) {
        // Localhost requests are auto-authenticated by the self-hosted engine;
        // a key can still be injected for hardened setups.
        let key = ProcessInfo.processInfo.environment["SUPERMEMORY_API_KEY"] ?? ""
        // Every answer-path request runs through the egress guard: a
        // non-loopback call is blocked and counted (M10 invariant enforcement).
        let guarded = URLSessionConfiguration.default
        guarded.installEgressGuard()
        let session = URLSession(configuration: guarded)
        let engine = EngineClient(baseURL: config.engine.baseURL, apiKey: key, session: session)
        let ollama = OllamaClient(baseURL: config.model.runtimeBaseURL,
                                  model: config.model.synthesis,
                                  keepAlive: config.model.keepAlive,
                                  session: session)
        self.scheduler = WorkScheduler()
        self.sync = BackgroundSync(engine: engine, config: config, scheduler: scheduler)

        // Build a query service scoped to a container — lets `/scope` re-target
        // subsequent queries without rebuilding the whole controller.
        let mountRoot = (config.smfs.mountPoint as NSString).expandingTildeInPath
        let syncIndex = sync.index
        let strengthLedger = StrengthLedger(path: NSHomeDirectory() + "/.supermemory/mnemo-strength.json")
        let answerCache = AnswerCache(ttl: 120)
        let smfsKey = (try? String(contentsOfFile: NSHomeDirectory() + "/.supermemory/data/api-key", encoding: .utf8))?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let maxHops = config.agentic.maxHops
        // Dev observatory (loopback, off by default): one bus, injected into every
        // query service and read by the dashboard's SSE server. Nil in normal runs.
        let devTrace: DevTrace? = (config.devtools.enabled
            || ProcessInfo.processInfo.environment["MNEMO_DEVTOOLS"] == "1") ? DevTrace() : nil
        self.devTrace = devTrace
        func makeService(_ container: String, _ tone: ResponseTone) -> QueryServing {
            // Agentic multi-hop over the mount (intelligence #1).
            let agentic = AgenticGrep(
                surface: SMFSGrep(smfsPath: NSHomeDirectory() + "/.local/bin/smfs",
                                  containerTag: container, apiKey: smfsKey,
                                  apiURL: config.engine.baseURL.absoluteString, mountRoot: mountRoot),
                planner: LLMHopPlanner(generator: ollama), maxHops: maxHops)
            return QueryService(
                retriever: engine,
                generator: ollama,
                spans: SpanResolver(docs: engine, chunkProvider: engine),
                defaults: SearchDefaults(searchMode: config.retrieval.defaultMode,
                                         rerank: config.retrieval.rerank,
                                         threshold: config.retrieval.threshold,
                                         limit: config.retrieval.limit,
                                         container: container),
                mountRoot: mountRoot,
                ingestIndex: syncIndex,
                profiles: engine,
                assembler: ContextAssembler(tokenBudget: 8000),
                effort: EffortPolicy(routing: config.effort.routing,
                                     extraction: config.effort.extraction,
                                     synthesis: config.effort.synthesis,
                                     multihop: config.effort.multihop),
                verifier: CitationVerifier(backend: LocalVerificationBackend(generator: ollama)),
                strength: strengthLedger,
                emptyFallback: true,
                tone: tone,
                relatedEnabled: true,
                cache: answerCache,
                rewriter: LLMQueryRewriter(generator: ollama),
                escalator: LLMRouterEscalator(generator: ollama),
                agentic: agentic,
                selfCorrect: true,
                documentSearchEnabled: true,
                conversationSink: engine,
                chatRecallEnabled: true,
                // M1a: stop discarding observability in the GUI path — record the
                // query log, stamp the model id, and report the PER-QUERY egress
                // delta so the notch trust footer reads real "0 outbound".
                logSink: QueryLogSinkFactory.make(config: config.logging),
                modelId: config.model.synthesis,
                egressCounter: { LoopbackGuardURLProtocol.blockedCount },
                trace: devTrace)
        }
        let handler = AppCommandHandler(engine: engine, config: config, container: "mnemo")
        self.handler = handler
        self.vm = NotchViewModel(defaultContainer: "mnemo",
                                 tone: ResponseTone(rawValue: config.uiTone) ?? .balanced,
                                 makeService: makeService, scheduler: scheduler, commands: handler)
        self.dictation = Dictation()
        self.narrator = Narrator()
        self.syncTask = sync.start()

        // Thumbs-up strengthens every cited memory (UI.md §8) — off the
        // interactive thread, and it can never crash the surface.
        vm.onFeedback = { sources in
            Task.detached(priority: .utility) {
                for s in sources { await strengthLedger.strengthen(s.docId) }
            }
        }

        let screen = NSScreen.main ?? NSScreen.screens[0]
        let notch = screen.mnemoNotchRectOrVirtual
        self.notchRect = notch
        self.screenFrame = screen.frame
        // The panel is sized once for the largest state (+ shadow bleed) and
        // NEVER resized or moved; all growth is SwiftUI content animation
        // (UI.md §4 — resizing the NSWindow per frame is the glitch).
        // Its top edge is flush with the SCREEN TOP so the surface overlays the
        // notch — anchoring at notch.minY leaves it dangling below.
        let panelSize = CGSize(width: Surface.readWidth + 2 * Surface.shadowBleed,
                               height: max(notch.height, 24) + Surface.maxBodyHeight + Surface.shadowBleed)
        let rect = NotchGeometry.panelRect(screenFrame: screen.frame, notch: notch, panelSize: panelSize)
        self.panel = NotchPanel(contentRect: rect)
        let hosting = NSHostingView(
            rootView: NotchSurfaceView(vm: vm, dictation: dictation, narrator: narrator, notchSize: notch.size))
        hosting.sizingOptions = []   // content must never drive the window size
        panel.contentView = hosting
        // First frame must be correct BEFORE the panel is ever visible
        // (UI.md §4.2): lay out now, then keep the panel resident forever —
        // summon is purely a content morph, never a window pop-in.
        hosting.layoutSubtreeIfNeeded()
        panel.orderFrontRegardless()

        // Voice endpointing: when the user stops speaking, auto-stop the mic and
        // submit what was transcribed — no tap needed. The surface goes straight
        // to searching with the transcript shown above the spinner.
        dictation.onEndpoint = { [weak self] in
            guard let self else { return }
            self.dictation.stop()
            if !self.vm.state.query.isEmpty { self.vm.beginSubmit() }
        }
    }

    func summon() {
        // Only from a truly idle surface: never while a query is still
        // streaming (phase can be .answering mid-stream), or a hover-out/in
        // spawns a duplicate session on top of the in-flight one.
        guard vm.state.phase == .idle, !vm.isQuerying else { return }
        vm.summon()
        panel.makeKeyAndOrderFront(nil)   // caret live immediately
    }

    func dismiss() {
        vm.dismiss()
        narrator.stop()
        if dictation.isListening { dictation.stop() }
        // Drop key back to the previous app, but keep the surface resident.
        if panel.isKeyWindow { panel.orderOut(nil) }
        panel.orderFrontRegardless()
    }

    /// Mouse-leave collapse hot rect (UI.md §5F): the notch plus the expanded
    /// surface as ONE region (+ grace margin), in screen coords. Nil while
    /// idle, dictating, or streaming — those must not auto-close.
    var mouseOutHotRect: CGRect? {
        let phase = vm.state.phase
        let hasDraft = !vm.state.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        guard NotchHover.shouldAutoCollapse(
            phase: phase,
            hasDraft: hasDraft,
            isListening: dictation.isListening,
            isQuerying: vm.isQuerying
        ) else { return nil }
        let width = Surface.inputWidth + 140
        let bodyHeight = Surface.trayHeight
        let h = notchRect.height + bodyHeight + 90
        return CGRect(x: notchRect.midX - width / 2, y: screenFrame.maxY - h, width: width, height: h)
    }
}
