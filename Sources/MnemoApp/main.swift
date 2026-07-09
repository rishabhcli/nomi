import AppKit
import MnemoCore

func mnemoConfigText() -> String? {
    let candidates = [
        FileManager.default.currentDirectoryPath + "/mnemo.toml",
        NSHomeDirectory() + "/Documents/6767/mnemo.toml",
    ]
    for c in candidates where FileManager.default.fileExists(atPath: c) {
        return try? String(contentsOfFile: c, encoding: .utf8)
    }
    return nil
}

guard let text = mnemoConfigText(), let config = try? MnemoConfig.load(from: text) else {
    FileHandle.standardError.write(Data("mnemo.toml missing or invalid\n".utf8))
    exit(2)
}
do { try config.validateInvariant() } catch {
    FileHandle.standardError.write(Data("INVARIANT VIOLATION: \(error)\n".utf8))
    exit(3)
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)   // no dock icon; system-surface feel
// A resident system surface must never App-Nap: the panel has to respond to
// hover/hotkey instantly, and napping tears down the status-item scene when
// launched from a non-GUI context ("workspace client connection invalidated").
let activity = ProcessInfo.processInfo.beginActivity(
    options: [.userInitiated, .automaticTerminationDisabled],
    reason: "Mnemo notch surface is resident")
_ = activity
let delegate = AppDelegate(config: config)
app.delegate = delegate
app.run()

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let config: MnemoConfig
    var controller: NotchController!
    var hover: HoverDetector!
    var hotkeyMonitor: Any?
    var debugHooks: DebugHooks?

    init(config: MnemoConfig) { self.config = config }

    func applicationDidFinishLaunching(_ n: Notification) {
        controller = NotchController(config: config)
        // No menu-bar item: the notch itself is the only affordance (UI.md §4).

        // Notch-hover summon + mouse-leave collapse (UI.md §5A/F).
        hover = HoverDetector(
            hoverZonePx: CGFloat(config.uiNotchHoverZonePx),
            onArm: { [weak self] in self?.controller.summon() },
            onLeave: { [weak self] in self?.controller.dismiss() },
            leaveRegion: { [weak self] in self?.controller.mouseOutHotRect })
        hover.start()

        // Click-outside: the panel resigning key collapses the surface —
        // unless the user is mid-dictation or an answer is streaming.
        NotificationCenter.default.addObserver(
            forName: NSWindow.didResignKeyNotification,
            object: controller.panel, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, let c = self.controller,
                      c.vm.state.phase != .idle,
                      c.vm.state.phase != .searching,
                      !c.dictation.isListening else { return }
                c.dismiss()
            }
        }

        // Global hotkey (cmd+shift+space) — keyboard-only summon/dismiss.
        hotkeyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] e in
            if e.modifierFlags.intersection([.command, .shift]) == [.command, .shift],
               e.charactersIgnoringModifiers == " " {
                Task { @MainActor in
                    guard let self, let c = self.controller else { return }
                    c.vm.state.phase == .idle ? c.summon() : c.dismiss()
                }
            }
        }

        debugHooks = DebugHooks.install(controller: controller)
    }

    @objc func dismissNotch() {
        controller.dismiss()
    }
}
