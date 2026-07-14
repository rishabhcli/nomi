import Foundation
import MnemoCore

/// The read model the dashboard renders at `/api/state` and as the first SSE
/// `snapshot` event. Codable → serialized straight to the browser. History
/// reuses `QueryLogEntry` (the per-query metrics record) verbatim.
public struct DashboardSnapshot: Codable, Sendable {
    public struct Process: Codable, Sendable {
        public let name: String
        public let isRunning: Bool
        public let boundAddress: String?
        public let isLoopback: Bool
        public let unhealthyReason: String?
        public init(name: String, isRunning: Bool, boundAddress: String?, isLoopback: Bool, unhealthyReason: String?) {
            self.name = name; self.isRunning = isRunning; self.boundAddress = boundAddress
            self.isLoopback = isLoopback; self.unhealthyReason = unhealthyReason
        }
    }
    public struct Health: Codable, Sendable {
        public let ollama: Process
        public let engine: Process
        public let smfs: Process
        public let allHealthyAndLoopback: Bool
        public init(ollama: Process, engine: Process, smfs: Process, allHealthyAndLoopback: Bool) {
            self.ollama = ollama; self.engine = engine; self.smfs = smfs
            self.allHealthyAndLoopback = allHealthyAndLoopback
        }
    }
    public struct Egress: Codable, Sendable {
        public let blockedCount: Int
        public let blockedHosts: [String]
        public let loopbackOK: Bool
        public init(blockedCount: Int, blockedHosts: [String], loopbackOK: Bool) {
            self.blockedCount = blockedCount; self.blockedHosts = blockedHosts; self.loopbackOK = loopbackOK
        }
    }
    public struct Invariant: Codable, Sendable {
        public let ok: Bool
        public let detail: String
        public init(ok: Bool, detail: String) { self.ok = ok; self.detail = detail }
    }
    public struct SLA: Codable, Sendable {
        public let firstTokenMs: Int
        public let sourcesRenderMs: Int
        public init(firstTokenMs: Int, sourcesRenderMs: Int) {
            self.firstTokenMs = firstTokenMs; self.sourcesRenderMs = sourcesRenderMs
        }
    }
    public struct Model: Codable, Sendable {
        public let id: String
        public init(id: String) { self.id = id }
    }

    public let health: Health
    public let egress: Egress
    public let invariant: Invariant
    public let sla: SLA
    public let model: Model
    public let history: [QueryLogEntry]

    public init(health: Health, egress: Egress, invariant: Invariant, sla: SLA, model: Model, history: [QueryLogEntry]) {
        self.health = health; self.egress = egress; self.invariant = invariant
        self.sla = sla; self.model = model; self.history = history
    }
}

// Bridges from the live MnemoCore models the app already has.
extension DashboardSnapshot.Process {
    public init(_ s: ProcessState) {
        self.init(name: s.name, isRunning: s.isRunning, boundAddress: s.boundAddress,
                  isLoopback: s.isLoopback, unhealthyReason: s.unhealthyReason)
    }
}
extension DashboardSnapshot.Health {
    public init(_ h: StackHealth) {
        self.init(ollama: .init(h.ollama), engine: .init(h.engine), smfs: .init(h.smfs),
                  allHealthyAndLoopback: h.allHealthyAndLoopback)
    }
}
extension DashboardSnapshot.Egress {
    public init(_ m: EgressMetrics) {
        self.init(blockedCount: m.blockedCount, blockedHosts: m.blockedHosts, loopbackOK: m.loopbackOK)
    }
}

/// What the dev server needs from the app: the live trace bus to stream, a
/// state snapshot to render, and a way to drive a query from the prompt box.
public protocol DashboardDataSource: Sendable {
    var trace: DevTrace { get }
    func snapshot() async -> DashboardSnapshot
    func ask(_ query: String) async
}
