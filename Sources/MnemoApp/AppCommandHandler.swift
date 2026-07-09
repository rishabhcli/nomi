// Agent-B audit B-013
import AppKit
import Foundation
import MnemoCore
import MnemoOrchestrator
import MnemoSupervisor

/// Wires the view-model's command/recovery intents to the real engine,
/// supervisor, and inspector. All actions are loopback-only.
@MainActor
final class AppCommandHandler: CommandHandling {
    let engine: EngineClient
    let config: MnemoConfig
    let container: String
    let suppression: SuppressionLedger
    let supervisor: ProcessSupervisor
    let launcher: SystemProcessLauncher

    init(engine: EngineClient, config: MnemoConfig, container: String) {
        self.engine = engine
        self.config = config
        self.container = container
        self.suppression = SuppressionLedger(path: NSHomeDirectory() + "/.supermemory/mnemo-suppression.json")
        self.launcher = SystemProcessLauncher(config: config)
        self.supervisor = ProcessSupervisor(config: config, launcher: launcher, probe: HTTPHealthProbe())
    }

    /// /profile and /inspect — a readable snapshot of what Mnemo knows.
    func profileText() async -> String {
        guard let profile = try? await engine.profile("what do you know about me", container: container) else {
            return "Couldn't reach the profile right now."
        }
        var lines: [String] = []
        if !profile.statics.isEmpty {
            lines.append("Stable facts:")
            lines += profile.statics.map { "• \($0)" }
        }
        if !profile.dynamics.isEmpty {
            lines.append("Current facts:")
            lines += profile.dynamics.prefix(12).map { "• \($0)" }
        }
        return lines.isEmpty ? "I don't know anything about you yet — add some files." : lines.joined(separator: "\n")
    }

    /// /forget <fact> — retract by content and suppress re-ingest (M9).
    func forget(_ fact: String) async {
        try? await engine.forgetMemory(content: fact, reason: RetireReason.userRetraction.text, container: container)
        await suppression.suppress(fact)
    }

    /// Working recovery for the dead-end states (M12 state machine).
    func recover(_ recovery: TerminalState.Recovery) async -> String? {
        switch recovery {
        case .restartEngine:
            do { try await supervisor.restart(.engine); return "Engine restarted." }
            catch { return "Couldn't restart the engine automatically. Run `mnemo engine start`." }
        case .loadModel:
            do { let m = try await launcher.ensureModelResident(); return "Model \(m) is loaded." }
            catch { return "Couldn't load the model. Run `ollama pull \(config.model.synthesis)`." }
        default:
            return nil
        }
    }

    func openMemoryFolder() {
        let path = (config.smfs.mountPoint as NSString).expandingTildeInPath
        try? FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: true)
        NSWorkspace.shared.open(URL(fileURLWithPath: path))
    }

    /// /preferences — the learned model of you, explicit and inspectable
    /// (beats-Siri #9: Siri's personalization is opaque; this one is legible).
    func preferencesText() async -> String {
        let ledger = StrengthLedger(path: NSHomeDirectory() + "/.supermemory/mnemo-strength.json")
        let memories = (try? await engine.listMemories(container: container)) ?? []
        return Preferences.summary(memories: memories, strength: await ledger.counts())
    }

    /// /entity <name> — a knowledge panel aggregated across the whole corpus
    /// (beats-Siri #4: an entity card over YOUR data, not a generic web card).
    func entityPanelText(_ name: String) async -> String {
        let hits = (try? await engine.search(SearchRequest(
            q: name, searchMode: "memories", rerank: false,
            threshold: 0.35, limit: 15, container: container))) ?? []
        let panel = EntityPanel.build(entity: name, from: hits)
        guard !panel.facts.isEmpty else { return "I don't have anything about “\(name)” yet." }
        var lines = ["What I know about \(name):"]
        lines += panel.facts.prefix(8).map { "• \($0)" }
        if !panel.sources.isEmpty {
            lines.append("From: " + panel.sources.map(\.title).joined(separator: ", "))
        }
        return lines.joined(separator: "\n")
    }

    /// Proactive digest on summon (beats-Siri #5) — what changed since last time.
    func digestText() async -> String {
        guard let docs = try? await engine.documentsList(container: container) else { return "" }
        let processing = docs.filter { $0.state == .processing || $0.state == .queued }.count
        let failed = docs.filter { $0.state == .error }.count
        let ready = docs.filter { $0.state == .ready }.count
        let lastKey = "mnemo.lastSummonAt"
        let last = UserDefaults.standard.object(forKey: lastKey) as? Date ?? .distantPast
        let iso = ISO8601DateFormatter()
        let newCount = docs.filter { d in
            (d.updatedAt.flatMap { iso.date(from: $0) } ?? .distantPast) > last
        }.count
        UserDefaults.standard.set(Date(), forKey: lastKey)
        // First run: everything is "new" — not a useful digest, stay quiet.
        let effectiveNew = last == .distantPast ? 0 : newCount
        return Digest.build(readyCount: ready, processingCount: processing, failedCount: failed,
                            newSinceLast: effectiveNew, conflictsResolved: 0)
    }
}
