import AppKit
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
    private enum FocusTarget: Hashable {
        case primaryAction
    }

    private enum AnnouncementState: Equatable {
        case requesting
        case ready(canContinue: Bool)
    }

    @ObservedObject var vm: NotchViewModel
    @FocusState private var focusedControl: FocusTarget?
    @State private var lastAnnouncement: AnnouncementState?
    @State private var panelIsKey = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityDifferentiateWithoutColor) private var differentiateWithoutColor
    @Environment(\.colorSchemeContrast) private var contrast

    private var snapshot: PermissionSnapshot? { vm.permissionOnboardingState.snapshot }
    private var isRequesting: Bool { vm.permissionOnboardingState.isRequesting }
    private var highContrast: Bool { contrast == .increased }
    private var enhancedContrast: Bool { highContrast || differentiateWithoutColor }

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            Label("Set up Mnemo", systemImage: "checkmark.shield.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white)

            Text("Approve voice access once. Protected files is optional and enables local Messages indexing.")
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(adaptiveTextOpacity(0.7)))
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
                    Divider().overlay(.white.opacity(adaptiveDividerOpacity(0.1)))
                    permissionRow(
                        "Microphone",
                        symbol: "mic.fill",
                        status: snapshot.microphone,
                        kind: .microphone,
                        optional: false
                    )
                    Divider().overlay(.white.opacity(adaptiveDividerOpacity(0.1)))
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
                    .focused($focusedControl, equals: .primaryAction)
                    .keyboardShortcut(.defaultAction)
                } else {
                    Button {
                        vm.requestVoicePermissions()
                    } label: {
                        Label("Allow voice", systemImage: "mic.badge.plus")
                    }
                    .buttonStyle(.glassProminent)
                    .focused($focusedControl, equals: .primaryAction)
                    .keyboardShortcut(.defaultAction)
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
        .task(id: vm.permissionOnboardingState) {
            await handleStateChange(vm.permissionOnboardingState)
        }
        .task(id: panelIsKey) {
            guard panelIsKey else {
                focusedControl = nil
                return
            }
            await handleStateChange(vm.permissionOnboardingState)
        }
        .background {
            OnboardingKeyWindowObserver { panelIsKey = $0 }
        }
        .overlay(alignment: .bottom) {
            HomeIndicator().frame(height: Surface.trayHandle)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Mnemo permissions")
    }

    @MainActor
    private func handleStateChange(_ state: PermissionOnboardingScreenState) async {
        if state.isRequesting || state == .hidden {
            announce(state)
        }
        await restoreFocus(for: state)
        guard panelIsKey, vm.permissionOnboardingState == state else { return }
        announce(state)
    }

    @MainActor
    private func restoreFocus(for state: PermissionOnboardingScreenState) async {
        focusedControl = nil
        await Task.yield()
        guard !Task.isCancelled, panelIsKey,
              vm.permissionOnboardingState == state else { return }

        if case .ready = state {
            focusedControl = .primaryAction
        }
    }

    private func announce(_ state: PermissionOnboardingScreenState) {
        let announcement: AnnouncementState?
        switch state {
        case .hidden:
            announcement = nil
        case .requesting:
            announcement = .requesting
        case .ready(let snapshot):
            announcement = .ready(canContinue: snapshot.voiceIsResolved)
        }
        guard let announcement else {
            lastAnnouncement = nil
            return
        }
        guard announcement != lastAnnouncement else { return }
        lastAnnouncement = announcement

        switch announcement {
        case .requesting:
            AccessibilityAnnouncer.post("Requesting voice permissions.")
        case .ready(let canContinue):
            let nextStep = canContinue ? " Continue." : " Allow voice to continue."
            AccessibilityAnnouncer.post("Permission setup ready.\(nextStep)")
        }
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
                .foregroundStyle(.white.opacity(adaptiveTextOpacity(0.82)))
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white)
                if optional, !status.isAuthorized {
                    Text("Optional")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.white.opacity(adaptiveTextOpacity(0.48)))
                }
            }
            Spacer()
            Text(statusLabel(status))
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(statusColor(status))
            if status == .denied || status == .restricted || (optional && !status.isAuthorized) {
                Button {
                    vm.openPermissionSettings(kind)
                } label: {
                    Image(systemName: "gearshape.fill")
                        .frame(width: 24, height: 24)
                        .modifier(OnboardingContrastForeground(enabled: enhancedContrast))
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

    private func statusColor(_ status: PermissionGrantStatus) -> Color {
        if status.isAuthorized {
            return enhancedContrast ? Color.white : Color.green
        }
        return .white.opacity(adaptiveTextOpacity(0.58))
    }

    private func adaptiveTextOpacity(_ normal: Double, primary: Bool = false) -> Double {
        SurfaceUX.IncreaseContrast.adaptiveTextOpacity(
            normal: normal,
            primary: primary,
            highContrast: highContrast,
            differentiateWithoutColor: differentiateWithoutColor
        )
    }

    private func adaptiveDividerOpacity(_ normal: Double) -> Double {
        SurfaceUX.IncreaseContrast.adaptiveDividerOpacity(
            normal: normal,
            highContrast: highContrast,
            differentiateWithoutColor: differentiateWithoutColor
        )
    }
}

private struct OnboardingContrastForeground: ViewModifier {
    let enabled: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if enabled { content.foregroundStyle(.white) }
        else { content }
    }
}

/// Reports key status for the exact NSWindow containing the onboarding view,
/// so focus can be restored after a system permission window returns control.
struct OnboardingKeyWindowObserver: NSViewRepresentable {
    let onKeyStatusChange: (Bool) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = OnboardingKeyWindowObserverView()
        view.onKeyStatusChange = onKeyStatusChange
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        (nsView as? OnboardingKeyWindowObserverView)?.onKeyStatusChange = onKeyStatusChange
    }
}

@MainActor
private final class OnboardingKeyWindowObserverView: NSView {
    var onKeyStatusChange: (Bool) -> Void = { _ in }
    private weak var observedWindow: NSWindow?
    private var lastReportedStatus: Bool?

    override func viewWillMove(toWindow newWindow: NSWindow?) {
        if let observedWindow {
            NotificationCenter.default.removeObserver(
                self, name: NSWindow.didBecomeKeyNotification, object: observedWindow)
            NotificationCenter.default.removeObserver(
                self, name: NSWindow.didResignKeyNotification, object: observedWindow)
        }
        observedWindow = nil
        lastReportedStatus = nil
        super.viewWillMove(toWindow: newWindow)
        guard let newWindow else { return }
        observedWindow = newWindow
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowDidBecomeKey),
            name: NSWindow.didBecomeKeyNotification,
            object: newWindow
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowDidResignKey),
            name: NSWindow.didResignKeyNotification,
            object: newWindow
        )
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        report(window?.isKeyWindow == true)
    }

    @objc private func windowDidBecomeKey() { report(true) }
    @objc private func windowDidResignKey() { report(false) }

    private func report(_ isKey: Bool) {
        guard lastReportedStatus != isKey else { return }
        lastReportedStatus = isKey
        onKeyStatusChange(isKey)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
