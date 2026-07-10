import Foundation

/// Fail-closed mnemo.toml schema — unknown keys rejected at startup.
public enum ConfigSchema {
    /// Allowed `[section].key` pairs. Keys not listed cause `ConfigError.unknownKey`.
    public static let allowed: [String: Set<String>] = [
        "engine": ["base_url", "byom", "embeddings", "timeout_ms"],
        "model": ["runtime_base_url", "synthesis", "fallback", "keep_alive"],
        "model.effort": ["routing", "extraction", "synthesis", "multihop"],
        "smfs": ["mount_point", "backing_store"],
        "sync": ["poll_seconds", "queue_max", "self_heal_enabled"],
        "retrieval": ["default_mode", "rerank", "threshold", "limit", "max_hops", "chunk_limit"],
        "agentic": ["max_hops"],
        "dreaming": ["enabled", "interval", "cold_threshold_days", "max_synthesis_tokens", "archive_never_retrieved"],
        "sla": ["first_token_ms", "sources_render_ms"],
        "ui": ["deployment_target", "summon", "hotkey", "summon_hotkey", "notch_hover_zone_px",
               "virtual_notch", "glass", "glass_prominence", "reduce_motion", "tone", "panel_level"],
        "privacy": ["egress_guard", "telemetry", "show_egress_indicator", "block_on_egress"],
        "logging": ["level", "rotation_mb"],
        "bench": ["warmup_runs", "sample_size"],
        "health": ["probe_interval"],
        "supervisor": ["restart_backoff"],
        "verification": ["strict_mode"],
        "profile": ["max_facts"],
        "ingest": ["poll_interval", "max_file_mb"],
        "context": ["max_tokens"],
        "router": ["escalation_threshold"],
        "media": ["retry_count"],
        "inspector": ["suppression_ttl_days"],
    ]

    public static let allowedLoggingLevels: Set<String> = ["off", "none", "error", "warn", "info", "debug"]

    public static func validateKeys(in parsed: [String: [String: TOMLValue]]) throws {
        for (section, keys) in parsed {
            guard let allowedKeys = allowed[section] else {
                if section.isEmpty { continue }
                throw ConfigError.unknownKey("unknown section [\(section)]")
            }
            for key in keys.keys where !allowedKeys.contains(key) {
                throw ConfigError.unknownKey("\(section).\(key)")
            }
        }
    }
}
