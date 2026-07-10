public struct ProcessState: Equatable, Sendable {
    public let name: String
    public let isRunning: Bool
    public let boundAddress: String?
    public init(name: String, isRunning: Bool, boundAddress: String?) {
        self.name = name
        self.isRunning = isRunning
        self.boundAddress = boundAddress
    }
    public var isLoopback: Bool {
        guard let a = boundAddress else { return false }
        return a.hasPrefix("127.0.0.1:") || a.hasPrefix("localhost:") || a.hasPrefix("127.0.0.1:nfs")
    }

    public var unhealthyReason: String? {
        if !isRunning { return "\(name) not running" }
        if !isLoopback { return "\(name) bound to non-loopback \(boundAddress ?? "?")" }
        return nil
    }
}

public struct StackHealth: Equatable, Sendable {
    public let ollama: ProcessState
    public let engine: ProcessState
    public let smfs: ProcessState

    public init(ollama: ProcessState, engine: ProcessState, smfs: ProcessState) {
        self.ollama = ollama
        self.engine = engine
        self.smfs = smfs
    }

    public var allHealthyAndLoopback: Bool {
        unhealthyReasons.isEmpty
    }

    public var unhealthyReasons: [String] {
        [ollama, engine, smfs].compactMap(\.unhealthyReason)
    }
}
