import Foundation
import MnemoCore

public enum ManagedProcess: String, CaseIterable, Sendable {
    case ollama, engine, smfs   // declaration order == start order
}

public protocol ProcessLauncher: Sendable {
    func launch(_ p: ManagedProcess) async throws
    func terminate(_ p: ManagedProcess) async
    func boundAddress(_ p: ManagedProcess) async -> String?
}

public enum SupervisorError: Error, Equatable { case failedToStart(ManagedProcess) }

public actor ProcessSupervisor {
    let config: MnemoConfig
    let launcher: ProcessLauncher
    let probe: HealthProbe

    public init(config: MnemoConfig, launcher: ProcessLauncher, probe: HealthProbe) {
        self.config = config
        self.launcher = launcher
        self.probe = probe
    }

    func healthURL(_ p: ManagedProcess) -> URL {
        switch p {
        case .ollama: return config.model.runtimeBaseURL
        case .engine: return config.engine.baseURL
        case .smfs:   return config.engine.baseURL   // smfs backs onto the engine
        }
    }

    public func startAll() async throws {
        try config.validateInvariant()
        for p in ManagedProcess.allCases {
            try await launcher.launch(p)
            if !(await waitUntilUp(p)) { throw SupervisorError.failedToStart(p) }
        }
    }

    public func stopAll() async {
        for p in ManagedProcess.allCases.reversed() {
            await launcher.terminate(p)
        }
    }

    public func restart(_ p: ManagedProcess) async throws {
        await launcher.terminate(p)
        if config.supervisor.restartBackoffMs > 0 {
            try? await Task.sleep(for: .milliseconds(config.supervisor.restartBackoffMs))
        }
        try await launcher.launch(p)
        if !(await waitUntilUp(p)) { throw SupervisorError.failedToStart(p) }
    }

    func waitUntilUp(_ p: ManagedProcess, attempts: Int = 20) async -> Bool {
        for _ in 0..<attempts {
            if await probe.isUp(healthURL(p)) { return true }
            try? await Task.sleep(for: .milliseconds(250))
        }
        return false
    }

    func state(_ p: ManagedProcess) async -> ProcessState {
        let addr = await launcher.boundAddress(p)
        let up = await probe.isUp(healthURL(p))
        return ProcessState(name: p.rawValue, isRunning: up, boundAddress: addr)
    }

    public func health() async -> StackHealth {
        StackHealth(ollama: await state(.ollama), engine: await state(.engine), smfs: await state(.smfs))
    }
}
