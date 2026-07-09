import Foundation
import MnemoCore

/// mnemoctl CLI help and flag parsing (Agent C observability).
enum MnemoCLI {
    static let commands: [String: String] = [
        "start": "Start ollama, engine, and smfs (loopback only)",
        "stop": "Stop all managed processes",
        "restart-engine": "Restart the Supermemory engine",
        "audit": "Verify mnemo-owned listeners are loopback-only (ports: 6767, 11434, 6420 Rivet, 11111 smfs)",
        "health": "Stack health probe; use --verbose for config dump",
        "egress-check": "Prove in-process egress guard blocks non-loopback",
        "ask": "Headless query path [--verify] [--then <follow-up>]",
        "bench": "Latency SLO report against mnemo.toml [sla]",
        "ingest-status": "Document ingest queue status",
        "watch-ingest": "Poll ingest state transitions",
        "memory": "Memory subcommands: list|add|forget|history|strengthen",
        "sync": "SMFS sync: force|self-heal",
        "dream": "Run consolidation pass",
        "inspect": "Memory inspector: show|delete|correct",
    ]

    static func printHelp(command: String? = nil) {
        if let cmd = command, let desc = commands[cmd] {
            print("mnemoctl \(cmd) — \(desc)")
            print("Flags: --verbose  Show reasoning trace / extra diagnostics")
            print("       --help     Show this help")
            return
        }
        print("mnemoctl — Mnemo stack control (loopback-only, offline-capable)")
        print("Usage: mnemoctl <command> [args] [--verbose] [--help]")
        print("")
        for (cmd, desc) in commands.sorted(by: { $0.key < $1.key }) {
            print("  \(cmd.padding(toLength: 16, withPad: " ", startingAt: 0)) \(desc)")
        }
        print("")
        print("Invariant exit codes: 0=OK 2=config 3=invariant 4=audit 64=usage")
    }

    static var verbose: Bool {
        CommandLine.arguments.contains("--verbose")
    }

    static var wantsHelp: Bool {
        CommandLine.arguments.contains("--help") || CommandLine.arguments.contains("-h")
    }
}

func printHealth(_ h: StackHealth, config: MnemoConfig, verbose: Bool) {
    print("version: \(BuildInfo.version) (\(BuildInfo.buildStamp))")
    print("ollama: up=\(h.ollama.isRunning) addr=\(h.ollama.boundAddress ?? "-")")
    print("engine: up=\(h.engine.isRunning) addr=\(h.engine.boundAddress ?? "-")")
    print("smfs:   up=\(h.smfs.isRunning) addr=\(h.smfs.boundAddress ?? "-")")
    if !h.unhealthyReasons.isEmpty {
        print("unhealthy: \(h.unhealthyReasons.joined(separator: "; "))")
    }
    print("allHealthyAndLoopback=\(h.allHealthyAndLoopback)")
    if verbose {
        print("config.engine.timeout_ms=\(config.engine.timeoutMs)")
        print("config.bench.sample_size=\(config.bench.sampleSize)")
        print("config.sla.first_token_ms=\(config.sla.firstTokenMs)")
        print("config.dreaming.interval_hours=\(config.dreaming.intervalHours)")
        print("config.privacy.telemetry=\(config.privacy.telemetry)")
        print("config.logging.level=\(config.logging.level)")
    }
}

func runAudit(launcher: SystemProcessLauncher) {
    let out = (try? launcher.capture("/usr/sbin/lsof", ["-iTCP", "-sTCP:LISTEN", "-n", "-P"])) ?? ""
    let ours = LoopbackAudit.parseLSOF(out).filter { LoopbackAudit.isMnemoOwned($0) }
    let bad = LoopbackAudit.nonLoopback(ours)
    if bad.isEmpty {
        let ports = ours.map(\.address).sorted().joined(separator: ", ")
        print("loopback OK (\(ours.count) mnemo-owned listeners: \(ports))")
        print("audit checks ports 6767 (engine), 11434 (ollama), 6420 (Rivet), 11111 (smfs)")
    } else {
        print("NON-LOOPBACK: \(bad)")
        exit(MnemoExitCode.auditFailure.rawValue)
    }
}

func runEgressCheck(config: MnemoConfig) async {
    LoopbackGuardURLProtocol.reset()
    let cfg = URLSessionConfiguration.ephemeral
    cfg.installEgressGuard()
    let session = URLSession(configuration: cfg)
    let probe = URL(string: "https://api.supermemory.ai/v4/search")!
    do {
        _ = try await session.data(from: probe)
        print("FAIL: egress was NOT blocked"); exit(1)
    } catch {
        let metrics = EgressMetrics.fromGuardSession(
            blockedCount: LoopbackGuardURLProtocol.blockedCount,
            loopbackReachable: false
        )
        print("guard blocked deliberate egress; blockedCount=\(metrics.blockedCount)")
        if !metrics.blockedHosts.isEmpty {
            print("blocked_hosts: \(metrics.blockedHosts.joined(separator: ", "))")
        }
    }
    let engineUp = (try? await session.data(from: config.engine.baseURL.appending(path: "/v3/settings"))) != nil
    print("loopback through guarded session: \(engineUp ? "OK" : "unreachable")")
}

/// Build structured log entry from query events (mnemoctl ask path).
func makeLogSink() -> FileQueryLogSink { FileQueryLogSink() }
