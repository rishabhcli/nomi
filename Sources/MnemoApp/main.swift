// Agent-B audit B-017
// Agent-B audit B-035
import AppKit
import MnemoCore
import MnemoOrchestrator

func mnemoConfigText() -> String? {
    var candidates = [
        FileManager.default.currentDirectoryPath + "/mnemo.toml",
        NSHomeDirectory() + "/Documents/6767/mnemo.toml",
    ]
    // A packaged .app ships its own config in Resources (launched via `open`,
    // the cwd is `/`, so the cwd candidate won't hit).
    if let bundled = Bundle.main.url(forResource: "mnemo", withExtension: "toml")?.path {
        candidates.insert(bundled, at: 0)
    }
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
    var hotkey: GlobalHotKey?
    var debugHooks: DebugHooks?
    var devTools: DevTools?

    init(config: MnemoConfig) { self.config = config }

    func applicationDidFinishLaunching(_ n: Notification) {
        // Single-instance: a second launch must not leave another resident notch
        // panel on screen. Each instance installs its own global hover monitor,
        // so every running copy pops open on hover → stacked "Ask Mnemo"
        // surfaces. Newest launch wins; terminate any older instance first.
        let me = NSRunningApplication.current
        for other in NSWorkspace.shared.runningApplications
        where other != me && (other.bundleIdentifier == "ai.mnemo.app"
                              || other.executableURL?.lastPathComponent == "MnemoApp") {
            other.terminate()
        }
        controller = NotchController(config: config)
        Task { @MainActor [weak self] in
            await self?.controller?.offerInitialOnboarding()
        }
        NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: app,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.controller?.vm.refreshPermissionOnboarding()
            }
        }
        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: app,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.controller?.screenParametersDidChange()
            }
        }
        // No menu-bar item: the notch itself is the only affordance (UI.md §4).

        // Notch-hover summon + mouse-leave collapse (UI.md §5A/F).
        hover = HoverDetector(
            hoverZonePx: CGFloat(config.uiNotchHoverZonePx),
            onMove: { [weak self] location in
                self?.controller?.panel.updatePointerLocation(location)
            },
            onArm: { [weak self] in self?.controller.summon(origin: .pointer) },
            onLeave: { [weak self] in self?.controller.dismiss() },
            leaveRegion: { [weak self] in self?.controller.mouseOutHotRect })
        hover.start()

        // Click-outside: the panel resigning key collapses the surface —
        // unless the user is mid-dictation, an answer is streaming, or a system
        // permission/starter flow temporarily owns focus. Disabled under debug
        // hooks so headless UI tests aren't collapsed when another app steals
        // key focus.
        if ProcessInfo.processInfo.environment["MNEMO_DEBUG_HOOKS"] != "1" {
            NotificationCenter.default.addObserver(
                forName: NSWindow.didResignKeyNotification,
                object: controller.panel, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.controller?.handlePanelDidResignKey()
                }
            }
        }

        // Registered global hotkey — reliable for an accessory app and sourced
        // from mnemo.toml rather than hardcoded event matching.
        if let chord = HotkeyChord.parse(config.ui.summonHotkey) {
            hotkey = GlobalHotKey(chord: chord) { [weak self] in
                guard let self, let c = self.controller else { return }
                c.vm.state.phase == .idle ? c.summon(origin: .hotkey) : c.dismiss()
            }
        }

        debugHooks = DebugHooks.install(controller: controller)
        devTools = DevTools.startIfEnabled(config: config, controller: controller)
    }

    @objc func dismissNotch() {
        controller.dismiss()
    }
}
