import Foundation

public enum PermissionGrantStatus: String, Codable, Equatable, Sendable {
    case notDetermined
    case authorized
    case denied
    case restricted
    case unavailable

    public var isResolved: Bool { self != .notDetermined }
    public var isAuthorized: Bool { self == .authorized }
}

public enum PermissionKind: String, Codable, Equatable, Sendable {
    case speechRecognition
    case microphone
    case fullDiskAccess
}

public struct PermissionSnapshot: Equatable, Sendable {
    public let speechRecognition: PermissionGrantStatus
    public let microphone: PermissionGrantStatus
    public let fullDiskAccess: PermissionGrantStatus

    public init(
        speechRecognition: PermissionGrantStatus,
        microphone: PermissionGrantStatus,
        fullDiskAccess: PermissionGrantStatus
    ) {
        self.speechRecognition = speechRecognition
        self.microphone = microphone
        self.fullDiskAccess = fullDiskAccess
    }

    public var voiceIsResolved: Bool {
        speechRecognition.isResolved && microphone.isResolved
    }

    public var voiceIsReady: Bool {
        speechRecognition.isAuthorized && microphone.isAuthorized
    }
}

public enum PermissionOnboardingPreference: String, Codable, Equatable, Sendable {
    case pending
    case completed
}

public enum PermissionOnboardingPolicy {
    public static func shouldOffer(
        preference: PermissionOnboardingPreference,
        snapshot: PermissionSnapshot
    ) -> Bool {
        _ = snapshot
        return preference == .pending
    }

    /// Speech and microphone each own a separate macOS prompt. A denial is a
    /// resolved choice and must not make onboarding reappear every launch. Full
    /// Disk Access is optional and Settings-only, so it never blocks completion.
    public static func canComplete(_ snapshot: PermissionSnapshot) -> Bool {
        snapshot.voiceIsResolved
    }
}

public enum PermissionOnboardingPreferenceTransition {
    public static func resolve(
        current: PermissionOnboardingPreference,
        requested: PermissionOnboardingPreference,
        isCancelled: Bool = false
    ) -> PermissionOnboardingPreference {
        guard current == .pending else { return current }
        if requested == .completed, isCancelled { return current }
        return requested
    }
}

public protocol PermissionOnboardingPreferenceStoring: Sendable {
    func load() async -> PermissionOnboardingPreference
    func transition(to preference: PermissionOnboardingPreference) async -> PermissionOnboardingPreference
}

public actor UserDefaultsPermissionOnboardingPreferenceStore: PermissionOnboardingPreferenceStoring {
    private let defaults: UserDefaults
    private let key: String

    public init(
        defaults: UserDefaults = .standard,
        key: String = "ai.mnemo.permission-onboarding.status.v1"
    ) {
        self.defaults = defaults
        self.key = key
    }

    public func load() -> PermissionOnboardingPreference {
        guard let raw = defaults.string(forKey: key),
              let value = PermissionOnboardingPreference(rawValue: raw)
        else { return .pending }
        return value
    }

    public func transition(
        to preference: PermissionOnboardingPreference
    ) -> PermissionOnboardingPreference {
        let current = load()
        let next = PermissionOnboardingPreferenceTransition.resolve(
            current: current,
            requested: preference,
            isCancelled: Task.isCancelled
        )
        if next != current { defaults.set(next.rawValue, forKey: key) }
        return next
    }
}

@MainActor
public protocol PermissionAuthorizing: AnyObject {
    func snapshot() -> PermissionSnapshot
    func requestVoicePermissions() async -> PermissionSnapshot
    func openSystemSettings(for permission: PermissionKind)
}
