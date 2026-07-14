import Foundation

/// A connection that was visible in a process socket table snapshot. This is
/// deliberately named an observation: polling cannot prove that a denied or
/// very short-lived `connect(2)` attempt occurred.
public struct ObservedNetworkConnection: Hashable, Sendable {
    public let command: String
    public let pid: Int
    public let localAddress: String
    public let remoteAddress: String
    public let state: String

    public init(
        command: String,
        pid: Int,
        localAddress: String,
        remoteAddress: String,
        state: String
    ) {
        self.command = command
        self.pid = pid
        self.localAddress = localAddress
        self.remoteAddress = remoteAddress
        self.state = state
    }

    public static func == (
        lhs: ObservedNetworkConnection,
        rhs: ObservedNetworkConnection
    ) -> Bool {
        lhs.command == rhs.command
            && lhs.pid == rhs.pid
            && lhs.localAddress == rhs.localAddress
            && lhs.remoteAddress == rhs.remoteAddress
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(command)
        hasher.combine(pid)
        hasher.combine(localAddress)
        hasher.combine(remoteAddress)
    }
}

public enum StackNetworkAuditFailure: String, Equatable, Sendable {
    case managedProcessesNotFound
    case processInspectionFailed
    case processTreeInspectionFailed
    case socketInspectionFailed
}

public enum StackNetworkSnapshot: Equatable, Sendable {
    case observed([ObservedNetworkConnection])
    case unavailable(StackNetworkAuditFailure)
}

public enum StackEgressAudit {
    public static func parseLSOF(_ text: String) -> [ObservedNetworkConnection] {
        text.split(separator: "\n").dropFirst().compactMap { line in
            let columns = line.split(
                separator: " ",
                omittingEmptySubsequences: true
            ).map(String.init)
            guard columns.count >= 9,
                  let pid = Int(columns[1]),
                  let endpoint = columns.first(where: { $0.contains("->") })
            else { return nil }

            let addresses = endpoint.split(separator: ">", maxSplits: 1).map(String.init)
            guard addresses.count == 2 else { return nil }
            let local = String(addresses[0].dropLast())
            let state = columns.last.flatMap { value -> String? in
                guard value.hasPrefix("("), value.hasSuffix(")") else { return nil }
                return String(value.dropFirst().dropLast())
            } ?? ""
            return ObservedNetworkConnection(
                command: columns[0],
                pid: pid,
                localAddress: local,
                remoteAddress: addresses[1],
                state: state
            )
        }
    }

    public static func nonLoopback(
        _ connections: [ObservedNetworkConnection]
    ) -> [ObservedNetworkConnection] {
        connections.filter { !LoopbackAudit.isLoopbackAddress($0.remoteAddress) }
    }

    public static func processTreePIDs(
        roots: Set<Int>,
        processList: String
    ) -> Set<Int> {
        var descendants = roots
        let relationships: [(pid: Int, parent: Int)] = processList
            .split(separator: "\n")
            .compactMap { line in
                let columns = line.split(separator: " ").compactMap { Int($0) }
                guard columns.count == 2 else { return nil }
                return (columns[0], columns[1])
            }
        var added = true
        while added {
            added = false
            for relationship in relationships where descendants.contains(relationship.parent) {
                added = descendants.insert(relationship.pid).inserted || added
            }
        }
        return descendants
    }
}

private final class ObservedEgressCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var observed = 0
    private var failures = 0
    private var available = true

    var observedValue: Int { lock.withLock { observed } }
    var failureValue: Int { lock.withLock { failures } }
    var isAvailable: Bool { lock.withLock { available } }
    var privacyViolationValue: Int { lock.withLock { observed + failures } }
    func add(_ amount: Int) {
        lock.withLock {
            observed += amount
            available = true
        }
    }
    func markAvailable() { lock.withLock { available = true } }
    func markUnavailable() {
        lock.withLock {
            // Count every failed sample. Query metrics consume a delta from
            // this cumulative counter, so sustained audit failure remains
            // visible without making metric reads mutate state.
            failures += 1
            available = false
        }
    }
    func reset() {
        lock.withLock {
            observed = 0
            failures = 0
            available = true
        }
    }
}

/// Counts non-loopback socket lifetimes observed across the managed process
/// tree. It complements the engine/Ollama Seatbelt boundary and the in-process
/// URLProtocol guard; it does not claim to count blocked syscalls.
public actor StackEgressMonitor {
    public typealias SnapshotProvider = @Sendable () async -> StackNetworkSnapshot

    private let snapshotProvider: SnapshotProvider
    private var active: Set<ObservedNetworkConnection> = []
    private var task: Task<Void, Never>?
    private nonisolated let counter = ObservedEgressCounter()
    public nonisolated var observedNonLoopbackConnections: Int { counter.observedValue }
    public nonisolated var auditFailureCount: Int { counter.failureValue }
    public nonisolated var auditAvailable: Bool { counter.isAvailable }
    public nonisolated var privacyViolationCount: Int { counter.privacyViolationValue }

    public init(snapshotProvider: @escaping SnapshotProvider) {
        self.snapshotProvider = snapshotProvider
    }

    public func sample() async {
        switch await snapshotProvider() {
        case let .observed(connections):
            let current = Set(StackEgressAudit.nonLoopback(connections))
            counter.add(current.subtracting(active).count)
            counter.markAvailable()
            active = current
        case .unavailable:
            counter.markUnavailable()
            active.removeAll()
        }
    }

    public func reset() {
        counter.reset()
        active.removeAll()
    }

    public func start(interval: Duration = .milliseconds(250)) {
        guard task == nil else { return }
        task = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                await self.sample()
                try? await Task.sleep(for: interval)
            }
        }
    }

    public func stop() {
        task?.cancel()
        task = nil
        active.removeAll()
    }
}
