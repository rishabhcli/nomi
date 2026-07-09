import Foundation

public enum ConfigError: Error, Equatable {
    case missingKey(String)
    case unknownKey(String)
    case parse(String)
    case notLoopback(field: String, value: String)
    case backingStoreMismatch(backing: String, engine: String)
    case invalidValue(field: String, reason: String)
}

public struct MnemoConfig: Equatable, Sendable {
    public struct Engine: Equatable, Sendable {
        public var baseURL: URL
        public var byom: String
        public var embeddings: String
        public var timeoutMs: Int
    }
    public struct Model: Equatable, Sendable {
        public var runtimeBaseURL: URL
        public var synthesis: String
        public var fallback: String
        public var keepAlive: String
    }
    public struct SMFS: Equatable, Sendable {
        public var mountPoint: String
        public var backingStore: URL
    }
    public struct Sync: Equatable, Sendable {
        public var pollSeconds: Int
        public var queueMax: Int
        public var selfHealEnabled: Bool
    }
    public struct Retrieval: Equatable, Sendable {
        public var defaultMode: String
        public var rerank: Bool
        public var threshold: Double
        public var limit: Int
        public var maxHops: Int
        public var chunkLimit: Int
    }
    public struct Effort: Equatable, Sendable {
        public var routing: String
        public var extraction: String
        public var synthesis: String
        public var multihop: String
    }
    public struct Agentic: Equatable, Sendable { public var maxHops: Int }
    public struct SLA: Equatable, Sendable {
        public var firstTokenMs: Int
        public var sourcesRenderMs: Int
    }
    public struct Dreaming: Equatable, Sendable {
        public var enabled: Bool
        public var intervalHours: Double
        public var coldThresholdDays: Int
        public var maxSynthesisTokens: Int
        public var archiveNeverRetrieved: Bool
    }
    public struct Privacy: Equatable, Sendable {
        public var showEgressIndicator: Bool
        public var egressGuard: String
        public var telemetry: String
        public var blockOnEgress: Bool
    }
    public struct UI: Equatable, Sendable {
        public var notchHoverZonePx: Int
        public var tone: String
        public var summonHotkey: String
        public var glassProminence: String
        public var panelLevel: String
    }
    public struct Logging: Equatable, Sendable {
        public var level: String
        public var rotationMb: Int
    }
    public struct Bench: Equatable, Sendable {
        public var warmupRuns: Int
        public var sampleSize: Int
    }
    public struct Health: Equatable, Sendable { public var probeIntervalMs: Int }
    public struct Supervisor: Equatable, Sendable { public var restartBackoffMs: Int }
    public struct Verification: Equatable, Sendable { public var strictMode: Bool }
    public struct Profile: Equatable, Sendable { public var maxFacts: Int }
    public struct Ingest: Equatable, Sendable {
        public var pollIntervalSeconds: Int
        public var maxFileMb: Int
    }
    public struct Context: Equatable, Sendable { public var maxTokens: Int }
    public struct Router: Equatable, Sendable { public var escalationThreshold: Double }
    public struct Media: Equatable, Sendable { public var retryCount: Int }
    public struct Inspector: Equatable, Sendable { public var suppressionTtlDays: Int }

    public var engine: Engine
    public var model: Model
    public var smfs: SMFS
    public var sync: Sync
    public var retrieval: Retrieval
    public var effort: Effort
    public var agentic: Agentic
    public var sla: SLA
    public var dreaming: Dreaming
    public var privacy: Privacy
    public var ui: UI
    public var logging: Logging
    public var bench: Bench
    public var health: Health
    public var supervisor: Supervisor
    public var verification: Verification
    public var profile: Profile
    public var ingest: Ingest
    public var context: Context
    public var router: Router
    public var media: Media
    public var inspector: Inspector

    public static func load(from text: String, strict: Bool = true) throws -> MnemoConfig {
        let t = try TOML.parse(text)
        if strict {
            try ConfigSchema.validateKeys(in: t)
        }
        func str(_ s: String, _ k: String) throws -> String {
            guard case let .string(v)? = t[s]?[k] else { throw ConfigError.missingKey("\(s).\(k)") }
            return v
        }
        func url(_ s: String, _ k: String) throws -> URL {
            let v = try str(s, k)
            guard let u = URL(string: v) else { throw ConfigError.parse("\(s).\(k)") }
            return u
        }
        func int(_ s: String, _ k: String) throws -> Int {
            guard case let .int(v)? = t[s]?[k] else { throw ConfigError.missingKey("\(s).\(k)") }
            return v
        }
        func dbl(_ s: String, _ k: String) throws -> Double {
            if case let .double(v)? = t[s]?[k] { return v }
            if case let .int(v)? = t[s]?[k] { return Double(v) }
            throw ConfigError.missingKey("\(s).\(k)")
        }
        func bool(_ s: String, _ k: String) throws -> Bool {
            guard case let .bool(v)? = t[s]?[k] else { throw ConfigError.missingKey("\(s).\(k)") }
            return v
        }
        func strOr(_ s: String, _ k: String, _ fallback: String) -> String {
            if case let .string(v)? = t[s]?[k] { return v }
            return fallback
        }
        func intOr(_ s: String, _ k: String, _ fallback: Int) -> Int {
            if case let .int(v)? = t[s]?[k] { return v }
            return fallback
        }
        func dblOr(_ s: String, _ k: String, _ fallback: Double) -> Double {
            if case let .double(v)? = t[s]?[k] { return v }
            if case let .int(v)? = t[s]?[k] { return Double(v) }
            return fallback
        }
        func boolOr(_ s: String, _ k: String, _ fallback: Bool) -> Bool {
            if case let .bool(v)? = t[s]?[k] { return v }
            return fallback
        }
        func parseIntervalHours(_ raw: String) -> Double {
            if raw.hasSuffix("h"), let h = Double(raw.dropLast()) { return h }
            if let h = Double(raw) { return h }
            return 6
        }
        let dreamInterval = strOr("dreaming", "interval", "6h")
        return MnemoConfig(
            engine: .init(
                baseURL: try url("engine", "base_url"),
                byom: try str("engine", "byom"),
                embeddings: try str("engine", "embeddings"),
                timeoutMs: intOr("engine", "timeout_ms", 30_000)
            ),
            model: .init(
                runtimeBaseURL: try url("model", "runtime_base_url"),
                synthesis: try str("model", "synthesis"),
                fallback: try str("model", "fallback"),
                keepAlive: try str("model", "keep_alive")
            ),
            smfs: .init(
                mountPoint: try str("smfs", "mount_point"),
                backingStore: try url("smfs", "backing_store")
            ),
            sync: .init(
                pollSeconds: try int("sync", "poll_seconds"),
                queueMax: intOr("sync", "queue_max", 4096),
                selfHealEnabled: boolOr("sync", "self_heal_enabled", true)
            ),
            retrieval: .init(
                defaultMode: try str("retrieval", "default_mode"),
                rerank: try bool("retrieval", "rerank"),
                threshold: try dbl("retrieval", "threshold"),
                limit: try int("retrieval", "limit"),
                maxHops: intOr("retrieval", "max_hops", intOr("agentic", "max_hops", 6)),
                chunkLimit: intOr("retrieval", "chunk_limit", 50)
            ),
            effort: .init(
                routing: strOr("model.effort", "routing", "low"),
                extraction: strOr("model.effort", "extraction", "low"),
                synthesis: strOr("model.effort", "synthesis", "medium"),
                multihop: strOr("model.effort", "multihop", "high")
            ),
            agentic: .init(maxHops: intOr("agentic", "max_hops", 6)),
            sla: .init(
                firstTokenMs: intOr("sla", "first_token_ms", 1500),
                sourcesRenderMs: intOr("sla", "sources_render_ms", 1000)
            ),
            dreaming: .init(
                enabled: boolOr("dreaming", "enabled", true),
                intervalHours: parseIntervalHours(dreamInterval),
                coldThresholdDays: intOr("dreaming", "cold_threshold_days", 30),
                maxSynthesisTokens: intOr("dreaming", "max_synthesis_tokens", 2048),
                archiveNeverRetrieved: boolOr("dreaming", "archive_never_retrieved", false)
            ),
            privacy: .init(
                showEgressIndicator: boolOr("privacy", "show_egress_indicator", true),
                egressGuard: strOr("privacy", "egress_guard", "enforce"),
                telemetry: strOr("privacy", "telemetry", "off"),
                blockOnEgress: boolOr("privacy", "block_on_egress", true)
            ),
            ui: .init(
                notchHoverZonePx: intOr("ui", "notch_hover_zone_px", 8),
                tone: strOr("ui", "tone", "balanced"),
                summonHotkey: strOr("ui", "hotkey", strOr("ui", "summon_hotkey", "cmd+shift+space")),
                glassProminence: strOr("ui", "glass", strOr("ui", "glass_prominence", "regular")),
                panelLevel: strOr("ui", "panel_level", "floating")
            ),
            logging: .init(
                level: strOr("logging", "level", "info"),
                rotationMb: intOr("logging", "rotation_mb", 50)
            ),
            bench: .init(
                warmupRuns: intOr("bench", "warmup_runs", 1),
                sampleSize: intOr("bench", "sample_size", 4)
            ),
            health: .init(probeIntervalMs: intOr("health", "probe_interval", 250)),
            supervisor: .init(restartBackoffMs: intOr("supervisor", "restart_backoff", 1000)),
            verification: .init(strictMode: boolOr("verification", "strict_mode", false)),
            profile: .init(maxFacts: intOr("profile", "max_facts", 20)),
            ingest: .init(
                pollIntervalSeconds: intOr("ingest", "poll_interval", intOr("sync", "poll_seconds", 30)),
                maxFileMb: intOr("ingest", "max_file_mb", 100)
            ),
            context: .init(maxTokens: intOr("context", "max_tokens", 8000)),
            router: .init(escalationThreshold: dblOr("router", "escalation_threshold", 0.6)),
            media: .init(retryCount: intOr("media", "retry_count", 2)),
            inspector: .init(suppressionTtlDays: intOr("inspector", "suppression_ttl_days", 365))
        )
    }
}

public func isLoopback(_ url: URL) -> Bool {
    guard let host = url.host else { return false }
    return isLoopbackHost(host)
}

public func isLoopbackHost(_ host: String) -> Bool {
    let h = host.lowercased()
    if h == "127.0.0.1" || h == "localhost" || h == "::1" { return true }
    if h.contains(".") {
        let octets = h.split(separator: ".")
        if octets.count == 4, octets[0] == "127" { return true }
        if octets[0] == "192" && octets.count > 1 && octets[1] == "168" { return false }
        if octets[0] == "10" { return false }
        if octets[0] == "172", let second = Int(octets[1]), (16...31).contains(second) { return false }
        if octets[0] == "0" { return false }
    }
    return false
}

extension MnemoConfig {
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
            throw ConfigError.backingStoreMismatch(
                backing: smfs.backingStore.absoluteString,
                engine: engine.baseURL.absoluteString
            )
        }
        if dreaming.intervalHours <= 0 {
            throw ConfigError.invalidValue(field: "dreaming.interval", reason: "must be > 0")
        }
        if bench.sampleSize <= 0 {
            throw ConfigError.invalidValue(field: "bench.sample_size", reason: "must be > 0")
        }
        if privacy.telemetry != "off" {
            throw ConfigError.invalidValue(field: "privacy.telemetry", reason: "must be off")
        }
        if !ConfigSchema.allowedLoggingLevels.contains(logging.level.lowercased()) {
            throw ConfigError.invalidValue(field: "logging.level", reason: "must be one of \(ConfigSchema.allowedLoggingLevels.sorted().joined(separator: ", "))")
        }
        if logging.rotationMb < 1 {
            throw ConfigError.invalidValue(field: "logging.rotation_mb", reason: "must be >= 1")
        }
        if sla.firstTokenMs <= 0 {
            throw ConfigError.invalidValue(field: "sla.first_token_ms", reason: "must be > 0")
        }
        if sla.sourcesRenderMs <= 0 {
            throw ConfigError.invalidValue(field: "sla.sources_render_ms", reason: "must be > 0")
        }
        if health.probeIntervalMs <= 0 {
            throw ConfigError.invalidValue(field: "health.probe_interval", reason: "must be > 0")
        }
        if supervisor.restartBackoffMs < 0 {
            throw ConfigError.invalidValue(field: "supervisor.restart_backoff", reason: "must be >= 0")
        }
    }

    // Backward-compatible accessors for MnemoApp (pre-C-agent field names).
    public var uiNotchHoverZonePx: Int { ui.notchHoverZonePx }
    public var uiTone: String { ui.tone }
}

public enum MnemoExitCode: Int32 {
    case ok = 0
    case configNotFound = 2
    case invariantViolation = 3
    case auditFailure = 4
    case healthFailure = 1
    case usage = 64
}
