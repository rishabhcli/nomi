import AppKit
import Foundation
import MnemoCore
import MnemoOrchestrator
import MnemoDevServer
import MnemoSupervisor

/// Wires the loopback developer observatory to the live app. OFF by default;
/// enabled only via `[devtools] enabled = true` in mnemo.toml or the
/// `MNEMO_DEVTOOLS=1` env var. Never in a normal/shipping run. The server binds
/// 127.0.0.1 exclusively and serves a self-contained page — nothing egresses.
@MainActor
final class DevTools {
    let trace: DevTrace
    private let config: MnemoConfig
    private var server: DevServer?

    private init(trace: DevTrace, config: MnemoConfig) {
        self.trace = trace
        self.config = config
    }

    static func startIfEnabled(config: MnemoConfig, controller: NotchController) -> DevTools? {
        let enabled = config.devtools.enabled
            || ProcessInfo.processInfo.environment["MNEMO_DEVTOOLS"] == "1"
        guard enabled, let trace = controller.devTrace else { return nil }
        let dt = DevTools(trace: trace, config: config)
        dt.start(controller: controller)
        return dt
    }

    private func start(controller: NotchController) {
        // The prompt box drives the SAME notch query path, so the dashboard shows
        // the exact pipeline the app runs. Captured on the main actor.
        let askHandler: @MainActor @Sendable (String) -> Void = { [weak controller] q in
            guard let c = controller else { return }
            c.summon(origin: .hotkey)
            c.vm.state.query = q
            c.vm.beginSubmit()
        }
        let source = DevToolsDataSource(trace: trace, config: config, askHandler: askHandler)
        let server = DevServer(port: UInt16(clamping: config.devtools.port),
                               dataSource: source, pageHTML: DashboardPage.html())
        do {
            try server.start()
            self.server = server
            let line = "▶ Mnemo Observatory (dev): http://127.0.0.1:\(config.devtools.port)/?token=\(server.token)\n"
            FileHandle.standardError.write(Data(line.utf8))
        } catch {
            FileHandle.standardError.write(Data("Mnemo devtools failed to start: \(error)\n".utf8))
        }
    }
}

/// Bridges the app's live state to the dashboard: the shared trace bus, a state
/// snapshot (health probes + egress + invariant + SLA + history), and an `ask`
/// that runs the real orchestrator.
final class DevToolsDataSource: DashboardDataSource, @unchecked Sendable {
    let trace: DevTrace
    private let config: MnemoConfig
    private let askHandler: @MainActor @Sendable (String) -> Void

    init(trace: DevTrace, config: MnemoConfig, askHandler: @escaping @MainActor @Sendable (String) -> Void) {
        self.trace = trace
        self.config = config
        self.askHandler = askHandler
    }

    func ask(_ query: String) async {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return }
        await MainActor.run { askHandler(q) }
    }

    func snapshot() async -> DashboardSnapshot {
        let egress = EgressMetrics.fromGuardSession(
            blockedCount: LoopbackGuardURLProtocol.blockedCount, loopbackReachable: true)
        let invariantOK = ((try? config.validateInvariant()) != nil)
        let health = await probeHealth()
        return DashboardSnapshot(
            health: .init(health),
            egress: .init(egress),
            invariant: .init(ok: invariantOK, detail: "loopback-only; smfs backing == engine"),
            sla: .init(firstTokenMs: config.sla.firstTokenMs, sourcesRenderMs: config.sla.sourcesRenderMs),
            model: .init(id: config.model.synthesis),
            history: Self.recentHistory())
    }

    private func probeHealth() async -> StackHealth {
        async let ollamaUp = Self.isUp(config.model.runtimeBaseURL)
        async let engineUp = Self.isUp(config.engine.baseURL)
        let smfsMount = (config.smfs.mountPoint as NSString).expandingTildeInPath
        let smfsMounted = FileManager.default.fileExists(atPath: smfsMount)
        let persistenceFailure = EnginePersistenceHealth.failureReason(
            at: NSHomeDirectory() + "/Library/Logs/Mnemo/engine.log"
        )
        let (o, e) = (await ollamaUp, await engineUp)
        return StackHealth(
            ollama: ProcessState(name: "ollama", isRunning: o, boundAddress: o ? Self.hostPort(config.model.runtimeBaseURL) : nil),
            engine: ProcessState(name: "engine", isRunning: e, boundAddress: e ? Self.hostPort(config.engine.baseURL) : nil),
            smfs: ProcessState(name: "smfs", isRunning: smfsMounted, boundAddress: smfsMounted ? Self.hostPort(config.smfs.backingStore) : nil),
            additionalUnhealthyReasons: persistenceFailure.map { [$0] } ?? []
        )
    }

    private static func isUp(_ url: URL) async -> Bool {
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        req.timeoutInterval = 1.2
        let cfg = URLSessionConfiguration.ephemeral
        cfg.timeoutIntervalForRequest = 1.2
        do {
            let (_, resp) = try await URLSession(configuration: cfg).data(for: req)
            return ((resp as? HTTPURLResponse)?.statusCode ?? 500) < 500
        } catch { return false }
    }

    private static func hostPort(_ url: URL) -> String {
        (url.host ?? "127.0.0.1") + (url.port.map { ":\($0)" } ?? "")
    }

    /// Recent query metrics, read from the structured log the app now writes.
    private static func recentHistory() -> [QueryLogEntry] {
        guard let data = FileManager.default.contents(atPath: MnemoLogPaths.appJSONL),
              let text = String(data: data, encoding: .utf8) else { return [] }
        let decoder = JSONDecoder()
        return text.split(separator: "\n").suffix(50).compactMap {
            try? decoder.decode(QueryLogEntry.self, from: Data($0.utf8))
        }
    }
}
