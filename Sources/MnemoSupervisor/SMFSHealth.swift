import Foundation

/// SMFS mount health probe — loopback NFS only (PLAN.md M0).
public enum SMFSHealth {
    public struct Status: Equatable, Sendable {
        public let mounted: Bool
        public let loopback: Bool
        public let mountPoint: String

        public init(mounted: Bool, loopback: Bool, mountPoint: String) {
            self.mounted = mounted
            self.loopback = loopback
            self.mountPoint = mountPoint
        }

        public var healthy: Bool { mounted && loopback }
    }

    public static func check(mountPoint: String, boundAddress: String?) -> Status {
        let expanded = (mountPoint as NSString).expandingTildeInPath
        let mounted = FileManager.default.fileExists(atPath: expanded)
        let loopback = boundAddress.map {
            LoopbackAudit.isLoopbackAddress($0) || $0.contains("127.0.0.1:nfs")
        } ?? false
        return Status(mounted: mounted, loopback: loopback, mountPoint: expanded)
    }
}
