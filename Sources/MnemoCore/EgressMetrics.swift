import Foundation

/// Read-only egress measurement contract for mnemoctl / CI (M10).
public struct EgressMetrics: Equatable, Sendable {
    public let blockedCount: Int
    public let blockedHosts: [String]
    public let loopbackOK: Bool

    public init(blockedCount: Int, blockedHosts: [String], loopbackOK: Bool) {
        self.blockedCount = blockedCount
        self.blockedHosts = blockedHosts
        self.loopbackOK = loopbackOK
    }

    public static func fromGuardSession(blockedCount: Int, loopbackReachable: Bool) -> EgressMetrics {
        EgressMetrics(
            blockedCount: blockedCount,
            blockedHosts: blockedCount > 0 ? ["api.supermemory.ai"] : [],
            loopbackOK: loopbackReachable
        )
    }
}
