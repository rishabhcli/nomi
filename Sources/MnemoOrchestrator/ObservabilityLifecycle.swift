import Foundation

/// Lifecycle observability surface for modules missing M12 hooks (Phase 2 D-0501..0750).
public enum ObservabilityLifecycle {
    public typealias LifecycleBranch = Provenance.LifecycleBranch

    public static func lifecycleEvents(branch: LifecycleBranch) -> [QueryEvent] {
        Provenance.lifecycleEvents(branch: branch)
    }
}

extension ConflictDetector {
    public typealias LifecycleBranch = ObservabilityLifecycle.LifecycleBranch
    public static func lifecycleEvents(branch: LifecycleBranch) -> [QueryEvent] {
        ObservabilityLifecycle.lifecycleEvents(branch: branch)
    }
}

extension Consolidation {
    public typealias LifecycleBranch = ObservabilityLifecycle.LifecycleBranch
    public static func lifecycleEvents(branch: LifecycleBranch) -> [QueryEvent] {
        ObservabilityLifecycle.lifecycleEvents(branch: branch)
    }
}

extension ContentHash {
    public typealias LifecycleBranch = ObservabilityLifecycle.LifecycleBranch
    public static func lifecycleEvents(branch: LifecycleBranch) -> [QueryEvent] {
        ObservabilityLifecycle.lifecycleEvents(branch: branch)
    }
}

extension EgressGuard {
    public typealias LifecycleBranch = ObservabilityLifecycle.LifecycleBranch
    public static func lifecycleEvents(branch: LifecycleBranch) -> [QueryEvent] {
        ObservabilityLifecycle.lifecycleEvents(branch: branch)
    }
}

extension EvidenceGathering {
    public typealias LifecycleBranch = ObservabilityLifecycle.LifecycleBranch
    public static func lifecycleEvents(branch: LifecycleBranch) -> [QueryEvent] {
        ObservabilityLifecycle.lifecycleEvents(branch: branch)
    }
}

extension IngestGate {
    public typealias LifecycleBranch = ObservabilityLifecycle.LifecycleBranch
    public static func lifecycleEvents(branch: LifecycleBranch) -> [QueryEvent] {
        ObservabilityLifecycle.lifecycleEvents(branch: branch)
    }
}

extension Inspector {
    public typealias LifecycleBranch = ObservabilityLifecycle.LifecycleBranch
    public static func lifecycleEvents(branch: LifecycleBranch) -> [QueryEvent] {
        ObservabilityLifecycle.lifecycleEvents(branch: branch)
    }
}

extension LLMSynthesizer {
    public typealias LifecycleBranch = ObservabilityLifecycle.LifecycleBranch
    public static func lifecycleEvents(branch: LifecycleBranch) -> [QueryEvent] {
        ObservabilityLifecycle.lifecycleEvents(branch: branch)
    }
}

extension MemoryDynamics {
    public typealias LifecycleBranch = ObservabilityLifecycle.LifecycleBranch
    public static func lifecycleEvents(branch: LifecycleBranch) -> [QueryEvent] {
        ObservabilityLifecycle.lifecycleEvents(branch: branch)
    }
}

extension NotchReducer {
    public typealias LifecycleBranch = ObservabilityLifecycle.LifecycleBranch
    public static func lifecycleEvents(branch: LifecycleBranch) -> [QueryEvent] {
        ObservabilityLifecycle.lifecycleEvents(branch: branch)
    }
}

extension Profile {
    public typealias LifecycleBranch = ObservabilityLifecycle.LifecycleBranch
    public static func lifecycleEvents(branch: LifecycleBranch) -> [QueryEvent] {
        ObservabilityLifecycle.lifecycleEvents(branch: branch)
    }
}

extension SyncEngine {
    public typealias LifecycleBranch = ObservabilityLifecycle.LifecycleBranch
    public static func lifecycleEvents(branch: LifecycleBranch) -> [QueryEvent] {
        ObservabilityLifecycle.lifecycleEvents(branch: branch)
    }
}

extension WorkScheduler {
    public typealias LifecycleBranch = ObservabilityLifecycle.LifecycleBranch
    public static func lifecycleEvents(branch: LifecycleBranch) -> [QueryEvent] {
        ObservabilityLifecycle.lifecycleEvents(branch: branch)
    }
}
