import AppKit
import SwiftUI
import MnemoOrchestrator

/// Verification hooks, active only with MNEMO_DEBUG_HOOKS=1 (never in normal
/// runs): drive the surface phases and capture geometry + rendered snapshots
/// so anchoring and shape can be verified headlessly (UI.md §11.1). All local —
/// DistributedNotificationCenter on this machine; nothing egresses.
@MainActor
final class DebugHooks {
    private let controller: NotchController
    private var tokens: [NSObjectProtocol] = []

    static func install(controller: NotchController) -> DebugHooks? {
        guard ProcessInfo.processInfo.environment["MNEMO_DEBUG_HOOKS"] == "1" else { return nil }
        return DebugHooks(controller: controller)
    }

    private init(controller: NotchController) {
        self.controller = controller
        let center = DistributedNotificationCenter.default()
        let actions: [(String, @MainActor () -> Void)] = [
            ("ai.mnemo.debug.summon", { [weak self] in self?.controller.summon() }),
            ("ai.mnemo.debug.dismiss", { [weak self] in self?.controller.dismiss() }),
            ("ai.mnemo.debug.typing", { [weak self] in self?.showTyping() }),
            ("ai.mnemo.debug.searching", { [weak self] in self?.showSearching() }),
            ("ai.mnemo.debug.demo", { [weak self] in self?.showDemoAnswer() }),
            ("ai.mnemo.debug.snapshot", { [weak self] in self?.snapshot() }),
            ("ai.mnemo.debug.orb", { [weak self] in self?.renderOrbStills() }),
            ("ai.mnemo.debug.cycle", { [weak self] in self?.cycleOpenClose() }),
            ("ai.mnemo.debug.dictate", { [weak self] in self?.startDictation() }),
            ("ai.mnemo.debug.stopdictate", { [weak self] in self?.controller.dictation.stop() }),
            ("ai.mnemo.debug.fakelisten", { [weak self] in self?.fakeListen() }),
            ("ai.mnemo.debug.stopfake", { [weak self] in self?.controller.dictation.isListening = false }),
        ]
        for (name, action) in actions {
            tokens.append(center.addObserver(forName: .init(name), object: nil, queue: .main) { _ in
                MainActor.assumeIsolated { action() }
            })
        }
        tokens.append(center.addObserver(forName: .init("ai.mnemo.debug.ask"), object: nil, queue: .main) { [weak self] note in
            let q = (note.userInfo?["query"] as? String)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            MainActor.assumeIsolated { self?.ask(query: q) }
        })
    }

    private func showSearching() {
        controller.summon()
        controller.vm.state.phase = .searching
        controller.vm.state.status = "Searching your memory…"
    }

    /// Typing state: shows the mic → send morph (reference IMG_1150).
    private func showTyping() {
        controller.summon()
        controller.vm.state.query = "Hello"
    }

    /// Drives the REAL on-device dictation path — the voice-drop UI and the
    /// crash-fix regression check. Summons, then starts the mic; logs the
    /// listening/problem state so a headless run can assert no force-quit.
    private func startDictation() {
        controller.summon()
        controller.dictation.start()
        let d = controller.dictation
        try? "dictate-started listening=\(d.isListening) problem=\(d.problem ?? "nil")\n"
            .appendToFile(atPath: "/tmp/mnemo-geometry.log")
    }

    /// Renders the voice "drop" (narrow pendant + orb) WITHOUT the mic, so the
    /// listening UI can be verified headlessly where speech permission isn't
    /// granted. Not a real capture — purely the drop geometry + orb shader.
    private func fakeListen() {
        controller.summon()
        controller.dictation.amplitude = 0.55
        controller.dictation.isListening = true
    }

    /// End-to-end query through the real orchestrator path (UI soak).
    private func ask(query q: String) {
        guard !q.isEmpty else {
            try? "ask-missing-query\n".appendToFile(atPath: "/tmp/mnemo-geometry.log")
            return
        }
        controller.summon()
        controller.vm.state.query = q
        controller.vm.beginSubmit()
        try? "ask-started query=\(q)\n".appendToFile(atPath: "/tmp/mnemo-geometry.log")
    }

    /// 10× open/close smoothness soak (UI.md §11): drives summon/dismiss
    /// repeatedly; watch for flashes, double-animations, or hangs.
    private func cycleOpenClose() {
        Task { @MainActor in
            for i in 0..<10 {
                controller.summon()
                try? await Task.sleep(for: .milliseconds(650))
                controller.dismiss()
                try? await Task.sleep(for: .milliseconds(500))
                try? "cycle \(i + 1) phase=\(controller.vm.state.phase)\n"
                    .appendToFile(atPath: "/tmp/mnemo-geometry.log")
            }
            try? "cycle-done\n".appendToFile(atPath: "/tmp/mnemo-geometry.log")
        }
    }

    /// Deterministic answering state — renders the reference layout offline
    /// (answer text · one quiet chip · thumbs).
    private func showDemoAnswer() {
        controller.summon()
        controller.vm.state = NotchState(
            phase: .answering, query: "Why did the scarecrow win an award?",
            answer: "Why did the scarecrow win an award? Because he was outstanding in his field!",
            sources: [SourceCard(title: "Riddleness", path: "~/Mnemo/memory/riddles.md",
                                 docId: "demo-1", relevance: 0.86,
                                 updatedAt: "2026-06-30T10:00:00Z")])
    }

    /// Geometry log + rendered PNG of the hosting view (no screen-recording
    /// permission needed): proves midX alignment and top-of-screen flushness.
    private func snapshot() {
        let panel = controller.panel
        let notch = controller.notchRect
        let screen = controller.screenFrame
        let f = panel.frame
        let midXDelta = f.midX - notch.midX
        let topDelta = screen.maxY - f.maxY
        let phase = controller.vm.state.phase
        var log = "phase=\(phase) panel.frame=\(f) notchRect=\(notch) screen=\(screen) "
        log += "midXDelta=\(midXDelta) topFlushDelta=\(topDelta) "
        log += "midXAligned=\(abs(midXDelta) < 1) topFlush=\(abs(topDelta) < 1)\n"
        try? log.appendToFile(atPath: "/tmp/mnemo-geometry.log")

        // Offscreen SwiftUI render (no screen-recording permission needed):
        // Liquid Glass falls back to its non-sampling material offscreen, but
        // shape, corners, anchoring, and content layout are the real thing.
        let content = NotchSurfaceView(vm: controller.vm, dictation: controller.dictation,
                                       narrator: controller.narrator, notchSize: notch.size)
            .frame(width: f.width, height: f.height, alignment: .top)
        let renderer = ImageRenderer(content: content)
        renderer.scale = 2
        renderer.isOpaque = false
        guard let tiff = renderer.nsImage?.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let png = rep.representation(using: .png, properties: [:]) else {
            try? "snapshot-failed phase=\(phase)\n".appendToFile(atPath: "/tmp/mnemo-geometry.log")
            return
        }
        let path = "/tmp/mnemo-snap-\(phase).png"
        try? png.write(to: URL(fileURLWithPath: path))
        try? "snapshot=\(path)\n".appendToFile(atPath: "/tmp/mnemo-geometry.log")

        // ScrollView/TextField are AppKit-backed and render as placeholders
        // offscreen; render the pure-SwiftUI answer zone separately.
        if phase == .answering {
            let blocks = AnswerZone(vm: controller.vm, dictation: controller.dictation,
                                    narrator: controller.narrator)
                .frame(width: Surface.readWidth)
                .background(Color.black)
            write(view: blocks, to: "/tmp/mnemo-snap-answer-blocks.png")
        }
    }

    /// The orb's amplitude curve as stills (UI.md §12.2): louder → bigger,
    /// brighter, more saturated. Rendered without a mic for determinism.
    private func renderOrbStills() {
        for amp in [0.0, 0.25, 0.5, 0.75, 1.0] {
            let view = VoiceOrbView(amplitude: amp)
                .frame(width: 170, height: 170)
                .background(Color(white: 0.10))
            write(view: view, to: "/tmp/mnemo-orb-\(Int(amp * 100)).png")
        }
        try? "orb stills written\n".appendToFile(atPath: "/tmp/mnemo-geometry.log")
    }

    private func write(view: some View, to path: String) {
        let renderer = ImageRenderer(content: view)
        renderer.scale = 2
        renderer.isOpaque = false
        guard let tiff = renderer.nsImage?.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let png = rep.representation(using: .png, properties: [:]) else { return }
        try? png.write(to: URL(fileURLWithPath: path))
    }
}

private extension String {
    func appendToFile(atPath path: String) throws {
        if let handle = FileHandle(forWritingAtPath: path) {
            defer { try? handle.close() }
            try handle.seekToEnd()
            try handle.write(contentsOf: Data(utf8))
        } else {
            try write(toFile: path, atomically: true, encoding: .utf8)
        }
    }
}
