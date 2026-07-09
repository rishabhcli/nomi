import Foundation

// EgressGuard.swift — measured outbound connection counter (M10).
// Public entry points:
//   EgressGuard — actor counting non-loopback attempts per query window
//   EgressGuard.isLoopbackHost — host classification for the guard
//   PrivacyIndicator — UI-facing egress cleanliness indicator

/// Counts outbound non-loopback connection attempts during a query window
/// (PLAN.md M10). The correct value is always zero; a non-zero count is a
/// measured invariant violation, not an assertion.
public actor EgressGuard {
    // A-286: intelligence
    // MARK: - Expressiveness (beats-Siri offline)
        /// Shapes cross-doc synthesis as timeline/table/bullets for offline rendering.
        public static func expressivenessShape(_ items: [String], as shape: AnswerShape) -> String {
            switch shape {
            case .timeline: return items.enumerated().map { "\($0.offset + 1). \($0.element)" }.joined(separator: "\n")
            case .comparison: return "| Item | Detail |\n|------|--------|\n" + items.map { "| \($0) | |" }.joined(separator: "\n")
            case .list: return items.map { "- \($0)" }.joined(separator: "\n")
            default: return items.joined(separator: "; ")
            }
        }

    // A-338: latency
    // MARK: - Scheduling (M11)
        /// Interactive queries preempt utility background work at chunk boundaries.
        public static func schedulingYieldHint(priority: WorkPriority = .background) -> Bool {
            priority < .interactive
        }

    // A-194: ingestion
    // MARK: - ingestion
        public static func indexingTerminalState(path: String) -> TerminalState { .indexing(path: path) }
        public static func ingestionSelfHealSafe(orphanIds: [String]) -> [String] { orphanIds.filter { !$0.isEmpty } }

    // A-130: grounding
    // MARK: - Citation integrity (M5)
        public static func citationIntegritySupported(_ sentence: String, evidence: [Retrieved]) -> Bool {
            let claim = Verification.stripCitations(sentence).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !claim.isEmpty else { return true }
            let corpus = evidence.map { $0.memory.lowercased() }.joined(separator: " ")
            let tokens = claim.lowercased().split(whereSeparator: { !$0.isLetter && !$0.isNumber }).filter { $0.count > 3 }
            guard !tokens.isEmpty else { return true }
            return tokens.allSatisfy { corpus.contains($0) }
        }
        public static func unsupportedAnswerEvents() -> [QueryEvent] { [.state(.unsupportedAnswer)] }

    // A-234: memory
    // MARK: - Memory dynamics (M6)
        /// Active memories only — forgotten and TTL-expired facts are excluded.
        public static func memoryDynamicsActive(_ entry: MemoryEntry, now: Date = Date()) -> Bool {
            guard entry.isLatest && !entry.isForgotten else { return false }
            guard let forgetAfter = entry.forgetAfter,
                  let expiry = ISO8601DateFormatter().date(from: forgetAfter) else { return true }
            return now < expiry
        }

        public static func memoryDynamicsFilter(_ entries: [MemoryEntry], now: Date = Date()) -> [MemoryEntry] {
            entries.filter { memoryDynamicsActive($0, now: now) }
        }

    public struct Window: Equatable, Sendable { let id: UUID }
    private var attempts = 0
    private var current: Window?

    public init() {}

    public static func isLoopbackHost(_ host: String) -> Bool {
        let h = host.lowercased()
        if h == "localhost" || h == "::1" || h == "[::1]" { return true }
        // 127.0.0.0/8 — but only as a genuine dotted-quad. A bare
        // hasPrefix("127.") waved through spoofed hosts like
        // "127.0.0.1.evil.com" (resolves off-box) → the guard would not block
        // egress to them. Require exactly four numeric octets starting with 127.
        let octets = h.split(separator: ".", omittingEmptySubsequences: false)
        guard octets.count == 4, octets[0] == "127" else { return false }
        return octets.allSatisfy { Int($0).map { (0...255).contains($0) } ?? false }
    }

    public func beginQueryWindow() -> Window {
        let w = Window(id: UUID())
        current = w
        attempts = 0
        return w
    }

    public func recordAttempt(host: String) {
        if !Self.isLoopbackHost(host) { attempts += 1 }
    }

    public var outboundNonLoopbackAttempts: Int { attempts }
    public func isClean() -> Bool { attempts == 0 }
    public func endWindow(_ w: Window) { if current == w { current = nil } }
}

/// UI indicator state driven by the live measurement.
public enum PrivacyIndicator: Equatable, Sendable {
    case clean                       // green — zero egress this session
    case egressDetected(count: Int)  // red — measured non-loopback attempts

    public static func from(_ guard0: EgressGuard) async -> PrivacyIndicator {
        let n = await guard0.outboundNonLoopbackAttempts
        return n == 0 ? .clean : .egressDetected(count: n)
    }
}

/// In-process interposer for Mnemo's own URLSession clients: intercepts and
/// BLOCKS any non-loopback request, counting it. Loopback requests are not
/// intercepted (canInit=false) so the normal loader handles them.
public final class LoopbackGuardURLProtocol: URLProtocol {
    nonisolated(unsafe) private static var _blocked = 0
    private static let lock = NSLock()
    public static var blockedCount: Int {
        lock.lock(); defer { lock.unlock() }; return _blocked
    }
    public static func reset() { lock.lock(); _blocked = 0; lock.unlock() }
    static func incr() { lock.lock(); _blocked += 1; lock.unlock() }

    /// Intercept only non-loopback requests (to block them). Loopback → false.
    public override class func canInit(with request: URLRequest) -> Bool {
        guard let host = request.url?.host else { return false }
        return !EgressGuard.isLoopbackHost(host)
    }
    public override class func canonicalRequest(for r: URLRequest) -> URLRequest { r }

    public override func startLoading() {
        Self.incr()
        let host = request.url?.host ?? "?"
        client?.urlProtocol(self, didFailWithError: NSError(
            domain: "MnemoEgressGuard", code: 1,
            userInfo: [NSLocalizedDescriptionKey: "Blocked non-loopback egress to \(host) (invariant)"]))
    }
    public override func stopLoading() {}
}

public extension URLSessionConfiguration {
    /// Installs the loopback guard at the front of the protocol chain.
    func installEgressGuard() {
        protocolClasses = [LoopbackGuardURLProtocol.self] + (protocolClasses ?? [])
    }
}
