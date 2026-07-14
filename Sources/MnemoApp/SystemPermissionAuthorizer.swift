import AppKit
import AVFoundation
import Darwin
import MnemoOrchestrator
import Speech

@MainActor
final class SystemPermissionAuthorizer: PermissionAuthorizing {
    func snapshot() -> PermissionSnapshot {
        PermissionSnapshot(
            speechRecognition: Self.speechStatus,
            microphone: Self.microphoneStatus,
            fullDiskAccess: Self.fullDiskAccessStatus
        )
    }

    func requestVoicePermissions() async -> PermissionSnapshot {
        // Mnemo is an LSUIElement app. It must be active while macOS presents
        // TCC sheets or the callbacks may never arrive.
        NSApplication.shared.activate(ignoringOtherApps: true)

        if Self.speechStatus == .notDetermined {
            _ = await withCheckedContinuation { continuation in
                SFSpeechRecognizer.requestAuthorization { status in
                    continuation.resume(returning: status)
                }
            }
        }
        if Self.microphoneStatus == .notDetermined {
            _ = await AVCaptureDevice.requestAccess(for: .audio)
        }
        return snapshot()
    }

    func openSystemSettings(for permission: PermissionKind) {
        let pane = switch permission {
        case .speechRecognition: "Privacy_SpeechRecognition"
        case .microphone: "Privacy_Microphone"
        case .fullDiskAccess: "Privacy_AllFiles"
        }
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(pane)")
        else { return }
        NSWorkspace.shared.open(url)
    }

    private static var speechStatus: PermissionGrantStatus {
        switch SFSpeechRecognizer.authorizationStatus() {
        case .notDetermined: .notDetermined
        case .authorized: .authorized
        case .denied: .denied
        case .restricted: .restricted
        @unknown default: .unavailable
        }
    }

    private static var microphoneStatus: PermissionGrantStatus {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .notDetermined: .notDetermined
        case .authorized: .authorized
        case .denied: .denied
        case .restricted: .restricted
        @unknown default: .unavailable
        }
    }

    /// Full Disk Access has no request API. Probe only the ability to open the
    /// Messages database; no contents are read and no prompt is generated.
    private static var fullDiskAccessStatus: PermissionGrantStatus {
        let path = MessagesReader.defaultDatabasePath
        guard FileManager.default.fileExists(atPath: path) else { return .unavailable }
        let descriptor = open(path, O_RDONLY | O_CLOEXEC)
        guard descriptor >= 0 else { return .denied }
        close(descriptor)
        return .authorized
    }
}
