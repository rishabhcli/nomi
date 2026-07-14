import MnemoOrchestrator
import SwiftUI

enum PermissionOnboardingScreenState: Equatable {
    case hidden
    case ready(PermissionSnapshot)
    case requesting(PermissionSnapshot)

    var snapshot: PermissionSnapshot? {
        switch self {
        case .hidden: nil
        case .ready(let snapshot), .requesting(let snapshot): snapshot
        }
    }

    var isRequesting: Bool {
        if case .requesting = self { return true }
        return false
    }

    var isAvailable: Bool { snapshot != nil }
}

struct PermissionOnboardingView: View {
    @ObservedObject var vm: NotchViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var snapshot: PermissionSnapshot? { vm.permissionOnboardingState.snapshot }
    private var isRequesting: Bool { vm.permissionOnboardingState.isRequesting }

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            Label("Set up Mnemo", systemImage: "checkmark.shield.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white)

            Text("Approve voice access once. Protected files is optional and enables local Messages indexing.")
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.7))
                .fixedSize(horizontal: false, vertical: true)

            if let snapshot {
                VStack(spacing: 0) {
                    permissionRow(
                        "Speech Recognition",
                        symbol: "waveform",
                        status: snapshot.speechRecognition,
                        kind: .speechRecognition,
                        optional: false
                    )
                    Divider().overlay(.white.opacity(0.1))
                    permissionRow(
                        "Microphone",
                        symbol: "mic.fill",
                        status: snapshot.microphone,
                        kind: .microphone,
                        optional: false
                    )
                    Divider().overlay(.white.opacity(0.1))
                    permissionRow(
                        "Protected files",
                        symbol: "externaldrive.fill.badge.checkmark",
                        status: snapshot.fullDiskAccess,
                        kind: .fullDiskAccess,
                        optional: true
                    )
                }
            }

            Spacer(minLength: 0)

            HStack(spacing: 12) {
                Spacer()
                if isRequesting {
                    ProgressView().controlSize(.small).tint(.white)
                } else if let snapshot, snapshot.voiceIsResolved {
                    Button {
                        vm.finishPermissionOnboarding()
                    } label: {
                        Label("Continue", systemImage: "arrow.right")
                    }
                    .buttonStyle(.glassProminent)
                } else {
                    Button {
                        vm.requestVoicePermissions()
                    } label: {
                        Label("Allow voice", systemImage: "mic.badge.plus")
                    }
                    .buttonStyle(.glassProminent)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(.horizontal, 22)
        .padding(.top, 18)
        .padding(.bottom, 20)
        .transition(Motion.blurMorph(reduceMotion: reduceMotion))
        .animation(
            Motion.adaptive(Motion.grow, reduceMotion: reduceMotion),
            value: vm.permissionOnboardingState
        )
        .overlay(alignment: .bottom) {
            HomeIndicator().frame(height: Surface.trayHandle)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Mnemo permissions")
    }

    private func permissionRow(
        _ title: String,
        symbol: String,
        status: PermissionGrantStatus,
        kind: PermissionKind,
        optional: Bool
    ) -> some View {
        HStack(spacing: 11) {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .semibold))
                .frame(width: 19)
                .foregroundStyle(.white.opacity(0.82))
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white)
                if optional, !status.isAuthorized {
                    Text("Optional")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.white.opacity(0.48))
                }
            }
            Spacer()
            Text(statusLabel(status))
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(status.isAuthorized ? Color.green : Color.white.opacity(0.58))
            if status == .denied || status == .restricted || (optional && !status.isAuthorized) {
                Button {
                    vm.openPermissionSettings(kind)
                } label: {
                    Image(systemName: "gearshape.fill")
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.glass)
                .help("Open Privacy & Security")
                .accessibilityLabel("Open settings for \(title)")
            }
        }
        .frame(height: 46)
    }

    private func statusLabel(_ status: PermissionGrantStatus) -> String {
        switch status {
        case .authorized: "Allowed"
        case .notDetermined: "Not set"
        case .denied: "Off"
        case .restricted: "Restricted"
        case .unavailable: "Unavailable"
        }
    }
}
