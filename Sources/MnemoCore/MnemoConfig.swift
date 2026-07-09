import Foundation

public enum ConfigError: Error, Equatable {
    case missingKey(String)
    case parse(String)
    case notLoopback(field: String, value: String)
    case backingStoreMismatch(backing: String, engine: String)
}

public struct MnemoConfig: Equatable, Sendable {
    public struct Engine: Equatable, Sendable { public var baseURL: URL; public var byom: String; public var embeddings: String }
    public struct Model: Equatable, Sendable { public var runtimeBaseURL: URL; public var synthesis: String; public var fallback: String; public var keepAlive: String }
    public struct SMFS: Equatable, Sendable { public var mountPoint: String; public var backingStore: URL }
    public struct Sync: Equatable, Sendable { public var pollSeconds: Int }
    public struct Retrieval: Equatable, Sendable { public var defaultMode: String; public var rerank: Bool; public var threshold: Double; public var limit: Int }
    public struct Effort: Equatable, Sendable { public var routing: String; public var extraction: String; public var synthesis: String; public var multihop: String }
    public struct Agentic: Equatable, Sendable { public var maxHops: Int }
    public struct SLA: Equatable, Sendable { public var firstTokenMs: Int; public var sourcesRenderMs: Int }

    public var engine: Engine
    public var model: Model
    public var smfs: SMFS
    public var sync: Sync
    public var retrieval: Retrieval
    public var effort: Effort
    public var agentic: Agentic
    public var sla: SLA
    public var uiNotchHoverZonePx: Int
    public var uiTone: String

    public static func load(from text: String) throws -> MnemoConfig {
        let t = try TOML.parse(text)
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
        // Optional scalar with a default (for sections added after M0).
        func strOr(_ s: String, _ k: String, _ fallback: String) -> String {
            if case let .string(v)? = t[s]?[k] { return v }
            return fallback
        }
        func intOr(_ s: String, _ k: String, _ fallback: Int) -> Int {
            if case let .int(v)? = t[s]?[k] { return v }
            return fallback
        }
        return MnemoConfig(
            engine: .init(baseURL: try url("engine", "base_url"), byom: try str("engine", "byom"), embeddings: try str("engine", "embeddings")),
            model: .init(runtimeBaseURL: try url("model", "runtime_base_url"), synthesis: try str("model", "synthesis"), fallback: try str("model", "fallback"), keepAlive: try str("model", "keep_alive")),
            smfs: .init(mountPoint: try str("smfs", "mount_point"), backingStore: try url("smfs", "backing_store")),
            sync: .init(pollSeconds: try int("sync", "poll_seconds")),
            retrieval: .init(defaultMode: try str("retrieval", "default_mode"), rerank: try bool("retrieval", "rerank"), threshold: try dbl("retrieval", "threshold"), limit: try int("retrieval", "limit")),
            effort: .init(routing: strOr("model.effort", "routing", "low"),
                          extraction: strOr("model.effort", "extraction", "low"),
                          synthesis: strOr("model.effort", "synthesis", "medium"),
                          multihop: strOr("model.effort", "multihop", "high")),
            agentic: .init(maxHops: intOr("agentic", "max_hops", 6)),
            sla: .init(firstTokenMs: intOr("sla", "first_token_ms", 1500),
                       sourcesRenderMs: intOr("sla", "sources_render_ms", 1000)),
            uiNotchHoverZonePx: intOr("ui", "notch_hover_zone_px", 8),
            uiTone: strOr("ui", "tone", "balanced")
        )
    }
}

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
