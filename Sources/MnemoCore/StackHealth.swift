public struct ProcessState: Equatable, Sendable {
    public let name: String
    public let isRunning: Bool
    public let boundAddress: String?   // "127.0.0.1:6767" or nil if unknown/down
    public init(name: String, isRunning: Bool, boundAddress: String?) {
        self.name = name
        self.isRunning = isRunning
        self.boundAddress = boundAddress
    }
    public var isLoopback: Bool {
        guard let a = boundAddress else { return false }
        return a.hasPrefix("127.0.0.1:") || a.hasPrefix("localhost:")
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
        [ollama, engine, smfs].allSatisfy { $0.isRunning && $0.isLoopback }
    }
}
